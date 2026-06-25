#!/bin/bash

echo -e "添加额外设备"

# ========== 原有 22.03 设备支持（保留）==========

# 加入nsy_g68-plus初始化网络配置脚本
cp -f $GITHUB_WORKSPACE/configs/swconfig_install package/base-files/files/etc/init.d/swconfig_install 2>/dev/null || true
chmod 755 package/base-files/files/etc/init.d/swconfig_install 2>/dev/null || true

# 集成 nsy_g68-plus WiFi驱动
mkdir -p package/base-files/files/lib/firmware/mediatek
cp -f $GITHUB_WORKSPACE/configs/mt7915_eeprom.bin package/base-files/files/lib/firmware/mediatek/mt7915_eeprom.bin 2>/dev/null || true
cp -f $GITHUB_WORKSPACE/configs/mt7916_eeprom.bin package/base-files/files/lib/firmware/mediatek/mt7916_eeprom.bin 2>/dev/null || true

# 删除会导致编译失败的补丁
rm -f target/linux/generic/hack-5.10/747-1-rtl8367b-support-rtl8367s.patch
rm -f target/linux/generic/hack-5.10/747-2-rtl8366_smi-phy-id.patch
rm -f target/linux/generic/hack-5.10/744-rtl8366_smi-fix-ce-debugfs.patch

# 电工大佬的rtl8367b驱动资源包
wget -q https://github.com/xiaomeng9597/files/releases/download/files/rtl8367b.tar.gz 2>/dev/null || true
tar -xvf rtl8367b.tar.gz 2>/dev/null || true

# ========== 22.03 rk35xx 逻辑（保留）==========

if [ "$1" = "rk35xx" ] || [ "$2" = "rk35xx" ]; then
    rm -f target/linux/rockchip/rk35xx/base-files/etc/board.d/02_network
    cp -f $GITHUB_WORKSPACE/configs/02_network target/linux/rockchip/rk35xx/base-files/etc/board.d/02_network 2>/dev/null || true

    # 增加nsy_g68-plus
    echo -e "\\\ndefine Device/nsy_g68-plus
\\\$(call Device/rk3568)
 DEVICE_VENDOR := NSY
 DEVICE_MODEL := G68
 DEVICE_DTS := rk3568-nsy-g68-plus
 SUPPORTED_DEVICES += nsy,g68-plus
 DEVICE_PACKAGES := kmod-nvme kmod-scsi-core kmod-thermal kmod-switch-rtl8306 kmod-switch-rtl8366-smi kmod-switch-rtl8366rb kmod-switch-rtl8366s kmod-hwmon-pwmfan kmod-leds-pwm kmod-r8125 kmod-r8168 kmod-switch-rtl8367b swconfig kmod-swconfig
endef
TARGET_DEVICES += nsy_g68-plus" >> target/linux/rockchip/image/rk35xx.mk

    # 增加nsy_g16-plus
    echo -e "\\\ndefine Device/nsy_g16-plus
\\\$(call Device/rk3568)
 DEVICE_VENDOR := NSY
 DEVICE_MODEL := G16
 DEVICE_DTS := rk3568-nsy-g16-plus
 SUPPORTED_DEVICES += nsy,g16-plus
 DEVICE_PACKAGES := kmod-nvme kmod-scsi-core kmod-thermal kmod-switch-rtl8306 kmod-switch-rtl8366-smi kmod-switch-rtl8366rb kmod-switch-rtl8366s kmod-hwmon-pwmfan kmod-leds-pwm kmod-r8125 kmod-r8168 kmod-switch-rtl8367b swconfig kmod-swconfig
endef
TARGET_DEVICES += nsy_g16-plus" >> target/linux/rockchip/image/rk35xx.mk

    # 增加bdy_g18-pro
    echo -e "\\\ndefine Device/bdy_g18-pro
\\\$(call Device/rk3568)
 DEVICE_VENDOR := BDY
 DEVICE_MODEL := G18
 DEVICE_DTS := rk3568-bdy-g18-pro
 SUPPORTED_DEVICES += bdy,g18-pro
 DEVICE_PACKAGES := kmod-nvme kmod-scsi-core kmod-thermal kmod-switch-rtl8306 kmod-switch-rtl8366-smi kmod-switch-rtl8366rb kmod-switch-rtl8366s kmod-hwmon-pwmfan kmod-leds-pwm kmod-r8125 kmod-r8168 kmod-switch-rtl8367b swconfig kmod-swconfig
endef
TARGET_DEVICES += bdy_g18-pro" >> target/linux/rockchip/image/rk35xx.mk

    # 添加dts
    cp -f $GITHUB_WORKSPACE/configs/rk3568-nsy-g68-plus.dts target/linux/rockchip/dts/rk3568/ 2>/dev/null || true
    cp -f $GITHUB_WORKSPACE/configs/rk3568-nsy-g16-plus.dts target/linux/rockchip/dts/rk3568/ 2>/dev/null || true
    cp -f $GITHUB_WORKSPACE/configs/rk3568-bdy-g18-pro.dts target/linux/rockchip/dts/rk3568/ 2>/dev/null || true

    # 22.03 .config
    sed -i "s/# CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_roc_k50s is not set/CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_roc_k50s=y/g" .config
    echo "
    CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_nsy_g68-plus=y
    CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_nsy_g16-plus=y
    CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_bdy_g18-pro=y
    " >> .config
fi

# ========== 24.10 armv8 逻辑（新增 K50S）==========

if [ "$1" = "istoreos-24.10" ] || [ "$2" = "rk35xx-24.10" ]; then
    echo "========== 添加 ROCEOS K50S (24.10 / armv8) =========="
    
    # 1. 注入设备定义到 armv8.mk（24.10 正确路径）
    cat >> target/linux/rockchip/image/armv8.mk << 'EOF'

define Device/roceos_k50s
  $(call Device/rk3568)
  DEVICE_VENDOR := ROCEOS
  DEVICE_MODEL := K50S
  DEVICE_DTS := rk3568-roc-k50s
  SUPPORTED_DEVICES += roceos,k50s
  DEVICE_PACKAGES := kmod-nvme kmod-scsi-core kmod-thermal kmod-hwmon-pwmfan kmod-leds-gpio kmod-r8125 kmod-brcmfmac kmod-btusb kmod-ata-ahci
endef
TARGET_DEVICES += roceos_k50s
EOF

    # 2. 复制 DTS 到 24.10 正确路径
    mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
    cp -f $GITHUB_WORKSPACE/configs/rk3568-roc-k50s.dts target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/ 2>/dev/null || true
    cp -f $GITHUB_WORKSPACE/configs/rk3568-roc-k50s.dtsi target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/ 2>/dev/null || true

    # 3. 复制网口初始化脚本到 24.10 正确路径
    mkdir -p target/linux/rockchip/armv8/base-files/etc/board.d/
    cp -f $GITHUB_WORKSPACE/configs/02_network_k50s target/linux/rockchip/armv8/base-files/etc/board.d/02_network 2>/dev/null || true
    chmod +x target/linux/rockchip/armv8/base-files/etc/board.d/02_network 2>/dev/null || true

    # 4. 在 .config 中启用 K50S（24.10 armv8 格式）
    sed -i "s/# CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_roceos_k50s is not set/CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_roceos_k50s=y/g" .config
    echo "CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_roceos_k50s=y" >> .config
    
    echo "K50S 设备添加完成"
fi
