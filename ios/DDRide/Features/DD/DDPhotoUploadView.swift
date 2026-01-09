//
//  DDPhotoUploadView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI
import FirebaseStorage

/// View for DD photo and car description upload
///
/// Features:
/// - Photo upload (camera or library)
/// - Circular photo display
/// - Car description text field
/// - Validation and save
struct DDPhotoUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DDViewModel

    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showSourceSelection = false
    @State private var carDescription = ""
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Photo section
                    photoSection

                    // Car description section
                    carDescriptionSection

                    // Save button
                    saveButton

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("Complete Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(
                    image: $selectedImage,
                    isPresented: $showImagePicker,
                    sourceType: imageSourceType
                )
            }
            .confirmationDialog("Choose Photo Source", isPresented: $showSourceSelection) {
                Button("Take Photo") {
                    imageSourceType = .camera
                    showImagePicker = true
                }

                Button("Choose from Library") {
                    imageSourceType = .photoLibrary
                    showImagePicker = true
                }

                Button("Cancel", role: .cancel) {}
            }
            .alert("Upload Error", isPresented: Binding(
                get: { uploadError != nil },
                set: { if !$0 { uploadError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = uploadError {
                    Text(error)
                }
            }
            .onAppear {
                // Pre-fill car description if exists
                carDescription = viewModel.ddAssignment?.carDescription ?? ""
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 16) {
            Text("Your Photo")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Photo display
            photoDisplay

            // Change photo button
            Button {
                showSourceSelection = true
            } label: {
                Label(selectedImage == nil && viewModel.ddAssignment?.photoURL == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }

            Text("Riders will use this photo to identify you")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var photoDisplay: some View {
        Group {
            if let image = selectedImage {
                // Show selected image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
            } else if let photoURL = viewModel.ddAssignment?.photoURL,
                      let url = URL(string: photoURL) {
                // Show existing photo from URL
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 150, height: 150)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
                    case .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                // Placeholder
                placeholderImage
            }
        }
        .frame(height: 150)
    }

    private var placeholderImage: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 150, height: 150)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Car Description Section

    private var carDescriptionSection: some View {
        VStack(spacing: 16) {
            Text("Car Description")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("e.g., Red Honda Civic", text: $carDescription)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 4)
                .autocapitalization(.words)

            Text("Help riders identify your vehicle")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Character limit
            HStack {
                Spacer()
                Text("\(carDescription.count)/50")
                    .font(.caption2)
                    .foregroundColor(carDescription.count > 50 ? .red : .secondary)
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task {
                await saveProfile()
            }
        } label: {
            HStack {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Save and Continue")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValid ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isValid || isUploading)
        .accessibilityLabel("Save profile")
        .accessibilityHint("Saves your photo and car description")
    }

    // MARK: - Validation

    private var isValid: Bool {
        // Must have either a new photo or existing photo
        let hasPhoto = selectedImage != nil || viewModel.ddAssignment?.photoURL != nil

        // Must have car description (not empty, max 50 chars)
        let hasCarDescription = !carDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && carDescription.count <= 50

        return hasPhoto && hasCarDescription
    }

    // MARK: - Save Profile

    private func saveProfile() async {
        isUploading = true
        uploadError = nil

        do {
            // Upload photo if new one selected
            if let image = selectedImage {
                try await viewModel.uploadPhoto(image)
            }

            // Update car description
            await viewModel.updateCarDescription(carDescription)

            // Success - dismiss
            isUploading = false
            dismiss()
        } catch {
            uploadError = error.localizedDescription
            isUploading = false
        }
    }
}

// MARK: - Image Picker

/// UIImagePickerController wrapper for SwiftUI
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true // Enable cropping to square
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Use edited image if available (cropped), otherwise original
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }

            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    DDPhotoUploadView(viewModel: DDViewModel())
}
