#!/bin/bash
# ============================================================
# iStoreOS 24.10 rk35xx-24.10 - ROCEOS K50S 设备添加脚本
# ============================================================

# 1. 添加 K50S 到 Rockchip ARMv8 设备列表
cat >> target/linux/rockchip/image/armv8.mk << 'EOF'

define Device/roceos_k50s
  DEVICE_VENDOR := ROCEOS
  DEVICE_MODEL := K50S
  SOC := rk3568
  DEVICE_PACKAGES := kmod-r8125 kmod-gpio-button-hotplug kmod-thermal
  IMAGE/sysupgrade.img.gz := boot-common | boot-script | pine64-img | gzip | append-metadata
endef
TARGET_DEVICES += roceos_k50s
EOF

# 2. 添加 board 检测（网口映射：3x PCIe RTL8125 + 2x GMAC）
# 这里假设 GMAC 对应 eth0/eth1，PCIe RTL8125 对应 eth2/eth3/eth4
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

# 3. 确保 .config 选中 K50S（如果 .config 已存在，则追加）
if [ -f .config ]; then
    # 先确保基础 target 配置存在
    echo "CONFIG_TARGET_rockchip=y" >> .config
    echo "CONFIG_TARGET_rockchip_armv8=y" >> .config
    echo "CONFIG_TARGET_rockchip_armv8_DEVICE_roceos_k50s=y" >> .config
fi

# 4. 复制 DTS 文件（请提前将 rk3568-roceos-k50s.dts 放在仓库根目录或脚本同级目录）
# 如果你已经有 DTS 文件，取消下面注释并修改路径：
# mkdir -p target/linux/rockchip/patches-6.6
# cp $GITHUB_WORKSPACE/rk3568-roceos-k50s.dts target/linux/rockchip/patches-6.6/

echo "ROCEOS K50S device registration completed."
