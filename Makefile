setup:
git config core.hooksPath .githooks
@echo "✅ Git hooks configured. Pre-push PR size check is now active."

.PHONY: setup
