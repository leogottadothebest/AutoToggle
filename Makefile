# AutoToggle 常用命令入口。运行 `make` 或 `make help` 查看全部。
.DEFAULT_GOAL := help

help: ## 列出所有可用命令
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

generate: ## 用 XcodeGen 重新生成工程
	xcodegen generate

build: ## 构建 Release（含签名门禁 + 通用二进制门禁）
	./scripts/build.sh

install: ## 覆盖安装到 /Applications
	./scripts/install.sh

test: ## 运行单元测试（Debug，ad-hoc 签名）
	xcodebuild -project AutoToggle.xcodeproj -scheme AutoToggle -configuration Debug -destination 'platform=macOS' test

lint: ## 运行 SwiftLint（若已安装）
	swiftlint --config .swiftlint.yml

format: ## 运行 SwiftFormat（若已安装）
	mint run swiftformat .

release: build install ## 构建并安装
