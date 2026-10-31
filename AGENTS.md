# Codex Project Instructions — Safe Korea

## Goal
Build a zero-cost, offline-first Flutter MVP for civilian air-raid preparedness in South Korea. The first milestone is a working Android emulator app, with iOS compatibility maintained. Do not publish or deploy.

## Workflow
1. Inspect the repository, OS, Flutter installation, Android SDK, and available simulators before changing anything.
2. If Flutter is missing, report exact installation steps; do not run privileged installers or change machine-wide settings without approval.
3. If this directory is empty and Flutter is available, initialize a Flutter app in this repository (`flutter create --org kr.example .`). Otherwise preserve the existing project.
4. Implement in small, testable increments. Run `flutter analyze` and `flutter test`, fixing failures. Summarize commands, changes, and remaining blockers.
5. Read CLAUDE.md if present, but treat AGENTS.md as the project guidance for Codex. Ask about conflicting instructions.
6. Request approval for destructive operations, external publishing, paid services, credential use, or risky commands. Never use blanket bypass of approvals.

## MVP scope
- Korean-language home screen with buttons: simulated air-raid drill, nearby shelters, emergency guidelines, family safety plan.
- Drill-only emergency screen with highly visible `훈련 / 테스트` label, clear next actions, and a return button.
- Emergency guidelines stored locally with official source references and reviewed date when available. Until verified, clearly mark content as draft and do not present it as authoritative.
- Shelter and family features may initially be honest placeholders; never invent real shelter locations, routes, or family statuses.
- Clean Material 3 design, large tap targets, accessible contrast, scalable text, and basic widget tests.

## Safety and reliability
- Never claim to receive actual government air-raid alerts. No real-alert notifications in this milestone.
- Never misrepresent a drill as a real alert; avoid alarming sounds during tests unless explicitly enabled.
- Do not claim an evacuation route or shelter is safe merely because it is close.
- Do not require network connectivity to read the core emergency guidance.
- Avoid collecting or uploading precise location or family data without clear opt-in.
- Use only verified government sources for operational instructions and identify last update dates.
- Avoid unnecessary dependencies, paid APIs, backend servers, analytics, and authentication in v0.1.

## Architecture
Flutter/Dart first. Organize UI under `lib/screens`, reusable widgets under `lib/widgets`, and offline content under `assets`. Add a Python backend only when a concrete server-side need arises.
