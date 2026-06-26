#!/bin/bash
# ==========================================
# iStoreOS 24.10 云编译 - ROCEOS K50S 自定义脚本
# 修复：DTS 路径 + CONFIG_TARGET_DEVICE_ 前缀
# ==========================================

cd openwrt

# ==========================================
# 1. 添加自定义 feeds（可选，如需添加额外软件源）
# ==========================================
# echo "src-git custom https://github.com/xxx/xxx.git" >> feeds.conf.default

# ==========================================
# 2. 修复 feeds install 依赖警告
# ==========================================
# 这些警告不影响编译，但可以通过以下方式静默：
# 确保 feeds 中已包含所需包

# ==========================================
# 3. 添加 ROCEOS K50S 设备支持
# ==========================================
echo "===== 添加 ROCEOS K50S 设备支持 ====="

# 复制 DTS 文件到内核源码目录（修复路径：添加 configs/ 前缀）
cp -f $GITHUB_WORKSPACE/configs/rk3568-roceos-k50s.dts target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
cp -f $GITHUB_WORKSPACE/configs/rk3568-roceos-k50s.dtsi target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/

# 注册 DTS 到内核 Makefile（避免重复添加）
if ! grep -q "rk3568-roceos-k50s.dts" target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/Makefile 2>/dev/null; then
    echo "dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3568-roceos-k50s.dtb" >> target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/Makefile
    echo "已添加 rk3568-roceos-k50s.dtb 到 Makefile"
else
    echo "rk3568-roceos-k50s.dtb 已存在于 Makefile，跳过"
fi

# 添加设备定义到 legacy.mk（24.10 使用 legacy.mk 而非 armv8.mk）
LEGACY_MK="target/linux/rockchip/image/legacy.mk"
if ! grep -q "roceos_k50s" "$LEGACY_MK" 2>/dev/null; then
cat >> "$LEGACY_MK" << 'EOF'

define Device/roceos_k50s
$(call Device/Legacy/rk3568,$(1))
  DEVICE_VENDOR := ROCEOS
  DEVICE_MODEL := K50S
  UBOOT_DEVICE_NAME := rk3568
  DEVICE_PACKAGES += kmod-r8125 kmod-phy-realtek
endef
TARGET_DEVICES += roceos_k50s
EOF
    echo "已添加 roceos_k50s 到 legacy.mk"
else
    echo "roceos_k50s 已存在于 legacy.mk，跳过"
fi

# 复制网口映射脚本
if [ -f "$GITHUB_WORKSPACE/configs/02_network_k50s" ]; then
    cp -f $GITHUB_WORKSPACE/configs/02_network_k50s package/base-files/files/etc/board.d/02_network
    chmod +x package/base-files/files/etc/board.d/02_network
    echo "已复制 02_network_k50s"
else
    echo "警告：configs/02_network_k50s 不存在，跳过网口映射"
fi

# ==========================================
# 4. 注入 K50S 目标配置（修复：使用 CONFIG_TARGET_DEVICE_ 前缀）
# ==========================================
echo "===== 注入 K50S 目标配置 ====="

# 确保目标架构配置正确
echo "CONFIG_TARGET_rockchip=y" >> .config
echo "CONFIG_TARGET_rockchip_armv8=y" >> .config

# 关键修复：使用 CONFIG_TARGET_DEVICE_ 前缀（而非 CONFIG_TARGET_）
echo "CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_roceos_k50s=y" >> .config

# 如果不需要编译其他设备，可以注释掉下面这行以节省编译时间
# echo "CONFIG_TARGET_ALL_PROFILES=y" >> .config

echo "===== K50S 配置注入完成 ====="

# ==========================================
# 5. 其他自定义修改（可选）
# ==========================================
# 例如：修改默认 IP、添加软件包等
# sed -i 's/192.168.1.1/192.168.50.1/g' package/base-files/files/bin/config_generate

echo "==================== diy-part2.sh 完成 ===================="
