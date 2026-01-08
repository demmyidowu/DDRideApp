#!/bin/bash

echo "🔍 Verifying DD Ride App Setup..."
echo ""

# Check directory structure
echo "✓ Checking directory structure..."
if [ -d ".claude/agents" ] && [ -d ".claude/skills" ] && [ -d ".claude/commands" ]; then
    echo "  ✅ Claude directories exist"
else
    echo "  ❌ Missing Claude directories"
    exit 1
fi

# Check CLAUDE.md
if [ -f "CLAUDE.md" ]; then
    echo "  ✅ CLAUDE.md exists"
else
    echo "  ❌ CLAUDE.md missing"
fi

# Check skills
echo ""
echo "✓ Checking custom skills..."
skills_count=$(find .claude/skills -name "SKILL.md" | wc -l | tr -d ' ')
echo "  Found $skills_count custom skills"

if [ -f ".claude/skills/ksu-auth-patterns/SKILL.md" ]; then
    echo "  ✅ ksu-auth-patterns skill exists"
else
    echo "  ❌ ksu-auth-patterns skill missing"
fi

if [ -f ".claude/skills/dd-app-testing-patterns/SKILL.md" ]; then
    echo "  ✅ dd-app-testing-patterns skill exists"
else
    echo "  ❌ dd-app-testing-patterns skill missing"
fi

# Check subagents
echo ""
echo "✓ Checking subagents..."
agents_count=$(find .claude/agents -name "*.md" | wc -l | tr -d ' ')
echo "  Found $agents_count subagents"

expected_agents=(
    "swift-ios-architect"
    "firebase-backend-engineer"
    "swiftui-developer"
    "business-logic-specialist"
    "location-services-expert"
    "sms-integration-specialist"
    "test-automator"
    "debugger"
    "deployment-engineer"
    "auth-security-specialist"
)

for agent in "${expected_agents[@]}"; do
    if [ -f ".claude/agents/${agent}.md" ]; then
        echo "  ✅ $agent"
    else
        echo "  ❌ $agent missing"
    fi
done

# Check tools installed
echo ""
echo "✓ Checking required tools..."

if command -v ruby &> /dev/null; then
    ruby_version=$(ruby -v | cut -d ' ' -f 2)
    echo "  ✅ Ruby $ruby_version"
else
    echo "  ❌ Ruby not installed"
fi

if command -v pod &> /dev/null; then
    pod_version=$(pod --version)
    echo "  ✅ CocoaPods $pod_version"
else
    echo "  ❌ CocoaPods not installed"
fi

if command -v node &> /dev/null; then
    node_version=$(node -v)
    echo "  ✅ Node.js $node_version"
else
    echo "  ❌ Node.js not installed"
fi

if command -v firebase &> /dev/null; then
    firebase_version=$(firebase --version)
    echo "  ✅ Firebase CLI $firebase_version"
else
    echo "  ❌ Firebase CLI not installed"
fi

if command -v claude &> /dev/null; then
    echo "  ✅ Claude Code installed"
else
    echo "  ❌ Claude Code not installed"
fi

echo ""
echo "📊 Setup Summary:"
echo "  • Skills: $skills_count/2"
echo "  • Subagents: $agents_count/10"
echo ""

if [ $agents_count -eq 10 ] && [ $skills_count -eq 2 ]; then
    echo "🎉 Setup complete! Ready to start development."
    echo ""
    echo "Next steps:"
    echo "1. Initialize Firebase: firebase init"
    echo "2. Create Xcode project: open ios/"
    echo "3. Start Claude Code: claude"
else
    echo "⚠️  Setup incomplete. Please review missing items above."
fi
