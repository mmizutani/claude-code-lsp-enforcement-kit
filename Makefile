# Validate Claude Code Plugin manifest (.claude-plugin/plugin.json)
.PHONY: validate-plugin-manifest
validate-plugin-manifest:
	./scripts/validate-plugin-manifest.sh

# Validate Claude Code Marketplace manifest (.claude-plugin/marketplace.json)
.PHONY: validate-marketplace-manifest
validate-marketplace-manifest:
	./scripts/validate-marketplace-manifest.sh

# Validate both manifests
.PHONY: validate
validate: validate-marketplace-manifest validate-plugin-manifest

# Run all tests (node:test)
.PHONY: test
test:
	node --test 'tests/*.test.cjs'
