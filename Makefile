.PHONY: help build install test lint format release

help:
	@echo "AutoToggle 开发命令："
	@echo "  make build    - 构建 Release 到 build/DerivedData"
	@echo "  make install  - 构建并原子覆盖 /Applications"
	@echo "  make test     - 运行单元测试（Debug ad-hoc，无需签名证书）"
	@echo "  make lint     - SwiftLint 检查"
	@echo "  make format   - SwiftFormat 格式化"
	@echo "  make release  - 构建 + 验证签名门禁"

build:
	./scripts/build.sh

install:
	./scripts/build.sh && ./scripts/install.sh

test:
	xcodegen generate
	xcodebuild -project AutoToggle.xcodeproj -scheme AutoToggle -configuration Debug -destination 'platform=macOS' test

lint:
	swiftlint --config .swiftlint.yml

format:
	swiftformat --config .swiftformat AutoToggle AutoToggleTests

release:
	./scripts/build.sh && ./scripts/verify-signing.sh build/DerivedData/Build/Products/Release/AutoToggle.app
