#!/bin/bash
# ============================================================
# iStoreOS 24.10 rk35xx-24.10 - ROCEOS K50S 设备注册
# ============================================================

set -e
cd openwrt

echo "==================== 1. 添加 K50S 到 legacy.mk ===================="
# 使用 Device/Legacy/rk3568 宏，继承 BOOT_SCRIPT/UBOOT_DEVICE_NAME
if ! grep -q "roceos_k50s" target/linux/rockchip/image/legacy.mk; then
    cat >> target/linux/rockchip/image/legacy.mk << 'EOF'

define Device/roceos_k50s
$(call Device/Legacy/rk3568,$(1))
  DEVICE_VENDOR := ROCEOS
  DEVICE_MODEL := K50S
  DEVICE_PACKAGES += kmod-r8125
endef
TARGET_DEVICES += roceos_k50s
EOF
    echo "✓ K50S 已添加到 legacy.mk"
else
    echo "✓ K50S 已存在于 legacy.mk"
fi

echo "==================== 2. 复制 DTS 到内核目录 ===================="
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
cp -v $GITHUB_WORKSPACE/rk3568-roceos-k50s.dts target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/ || true
cp -v $GITHUB_WORKSPACE/rk3568-roceos-k50s.dtsi target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/ || true

echo "==================== 3. 修改内核 DTS Makefile ===================="
# 方式 A: 如果缓存命中，内核源码已存在，直接修改 build_dir 中的 Makefile
for makefile in build_dir/target-*/linux-rockchip_armv8/linux-6.6.*/arch/arm64/boot/dts/rockchip/Makefile; do
    if [ -f "$makefile" ] && ! grep -q "rk3568-roceos-k50s.dtb" "$makefile"; then
        # 在 rk3568-roc-pc.dtb 之前插入
        sed -i '/dtb-\$(CONFIG_ARCH_ROCKCHIP) += rk3568-roc-pc.dtb/i dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-roceos-k50s.dtb' "$makefile"
        echo "✓ 已修改内核 Makefile: $makefile"
    fi
done

# 方式 B: 创建 patch，用于内核重新解压的场景
mkdir -p target/linux/rockchip/patches-6.6
cat > target/linux/rockchip/patches-6.6/999-roceos-k50s-dtb.patch << 'PATCH_EOF'
--- a/arch/arm64/boot/dts/rockchip/Makefile
+++ b/arch/arm64/boot/dts/rockchip/Makefile
@@ -71,6 +71,7 @@
 dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-nanopi-r5s.dtb
 dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-odroid-m1.dtb
 dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-panther-x2.dtb
+dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-roceos-k50s.dtb
 dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-roc-pc.dtb
 dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-rock-3a.dtb
PATCH_EOF
echo "✓ 已创建 DTS Makefile patch"

echo "==================== 4. 添加 board 网口映射 ===================="
mkdir -p target/linux/rockchip/armv8/base-files/etc/board.d
cat > target/linux/rockchip/armv8/base-files/etc/board.d/02_network << 'EOF'
#!/bin/sh

. /lib/functions/uci-defaults.sh

board_config_update

case $(board_name) in
roceos,k50s)
	ucidef_set_interfaces_lan_wan "eth0 eth1 eth2 eth3" "eth4"
	;;
esac

board_config_flush

exit 0
EOF
chmod +x target/linux/rockchip/armv8/base-files/etc/board.d/02_network
echo "✓ 02_network 已创建"

echo "==================== 5. 确保 .config 包含 K50S ===================="
# 追加到 .config（如果仓库根目录有 .config，它已经被复制到 openwrt/.config）
echo "CONFIG_TARGET_rockchip=y" >> .config
echo "CONFIG_TARGET_rockchip_armv8=y" >> .config
echo "CONFIG_TARGET_rockchip_armv8_DEVICE_roceos_k50s=y" >> .config

# 运行 defconfig 使配置生效并验证
echo "==================== 6. 运行 make defconfig ===================="
make defconfig

echo "==================== 7. 验证 ===================="
echo "--- legacy.mk 中的 K50S ---"
grep -A 6 "roceos_k50s" target/linux/rockchip/image/legacy.mk || echo "ERROR: 未找到"
echo "--- .config 中的 K50S ---"
grep "roceos_k50s" .config || echo "ERROR: CONFIG 未找到"
echo "--- DTS 文件 ---"
ls -la target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3568-roceos* 2>/dev/null || echo "ERROR: DTS 未找到"
echo "==================== 完成 ===================="
