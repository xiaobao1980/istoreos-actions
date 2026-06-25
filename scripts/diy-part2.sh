#!/bin/bash
# ==========================================
# iStoreOS 24.10 ROCEOS K50S 完整设备补丁
# ==========================================
set -e

# ---- 1. 创建 K50S DTS（RK3568 + 5网口）----
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
mkdir -p "$DTS_DIR"

cat > "$DTS_DIR/rk3568-roceos-k50s.dts" << 'DTS_EOF'
/dts-v1/;
#include "rk3568.dtsi"
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/pinctrl/rockchip.h>

/ {
    model = "ROCEOS K50S";
    compatible = "roceos,k50s", "rockchip,rk3568";

    aliases {
        ethernet0 = &gmac0;
        ethernet1 = &gmac1;
        mmc0 = &sdmmc0;
        mmc1 = &sdhci;
    };

    chosen {
        stdout-path = "serial2:1500000n8";
    };
};

&gmac0 {
    phy-mode = "rgmii";
    clock_in_out = "output";
    /* 注意：以下 GPIO 需按实际硬件调整，此处为常见参考值 */
    snps,reset-gpio = <&gpio0 RK_PC7 GPIO_ACTIVE_LOW>;
    snps,reset-active-low;
    snps,reset-delays-us = <0 10000 50000>;
    assigned-clocks = <&cru SCLK_GMAC0_RX_TX>, <&cru SCLK_GMAC0>;
    assigned-clock-rates = <0>, <125000000>;
    assigned-clock-parents = <&cru SCLK_GMAC0_RMII_SPEED>;
    pinctrl-names = "default";
    pinctrl-0 = <&gmac0_miim
             &gmac0_tx_bus2
             &gmac0_rx_bus2
             &gmac0_rgmii_clk
             &gmac0_rgmii_bus>;
    status = "okay";
};

&gmac1 {
    phy-mode = "rgmii";
    clock_in_out = "output";
    snps,reset-gpio = <&gpio0 RK_PB7 GPIO_ACTIVE_LOW>;
    snps,reset-active-low;
    snps,reset-delays-us = <0 10000 50000>;
    assigned-clocks = <&cru SCLK_GMAC1_RX_TX>, <&cru SCLK_GMAC1>;
    assigned-clock-rates = <0>, <125000000>;
    assigned-clock-parents = <&cru SCLK_GMAC1_RMII_SPEED>;
    pinctrl-names = "default";
    pinctrl-0 = <&gmac1_miim
             &gmac1_tx_bus2
             &gmac1_rx_bus2
             &gmac1_rgmii_clk
             &gmac1_rgmii_bus>;
    status = "okay";
};

/* 3 个 PCIe RTL8125 */
&pcie2x1 {
    reset-gpios = <&gpio0 RK_PC4 GPIO_ACTIVE_HIGH>;
    status = "okay";
};

&pcie3x1 {
    reset-gpios = <&gpio0 RK_PC6 GPIO_ACTIVE_HIGH>;
    status = "okay";
};

&pcie3x2 {
    reset-gpios = <&gpio0 RK_PC5 GPIO_ACTIVE_HIGH>;
    status = "okay";
};

&uart2 {
    status = "okay";
};

&sdhci {
    bus-width = <8>;
    mmc-hs200-1_8v;
    non-removable;
    status = "okay";
};

&sdmmc0 {
    bus-width = <4>;
    cap-mmc-highspeed;
    cap-sd-highspeed;
    disable-wp;
    pinctrl-names = "default";
    pinctrl-0 = <&sdmmc0_bus4 &sdmmc0_clk &sdmmc0_cmd &sdmmc0_det>;
    status = "okay";
};
DTS_EOF

# ---- 2. 注册 dtb 到内核 Makefile ----
MAKEFILE="$DTS_DIR/Makefile"
if [ -f "$MAKEFILE" ]; then
    if ! grep -q "rk3568-roceos-k50s.dtb" "$MAKEFILE"; then
        echo 'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-roceos-k50s.dtb' >> "$MAKEFILE"
    fi
else
    echo 'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-roceos-k50s.dtb' > "$MAKEFILE"
fi

# ---- 3. 添加 Board 定义到 image Makefile ----
# iStoreOS 24.10 常用 rk35xx.mk，部分旧版用 armv8.mk
IMAGE_MK=""
if [ -f "target/linux/rockchip/image/rk35xx.mk" ]; then
    IMAGE_MK="target/linux/rockchip/image/rk35xx.mk"
elif [ -f "target/linux/rockchip/image/armv8.mk" ]; then
    IMAGE_MK="target/linux/rockchip/image/armv8.mk"
fi

if [ -n "$IMAGE_MK" ] && ! grep -q "roceos_k50s" "$IMAGE_MK"; then
    cat >> "$IMAGE_MK" << 'MK_EOF'

define Device/roceos_k50s
  DEVICE_VENDOR := ROCEOS
  DEVICE_MODEL := K50S
  SOC := rk3568
  DEVICE_PACKAGES := kmod-r8169
endef
TARGET_DEVICES += roceos_k50s
MK_EOF
    echo "Added K50S to $IMAGE_MK"
fi

# ---- 4. 强制 .config 选中 K50S ----
if grep -q "CONFIG_TARGET_rockchip_rk35xx=y" .config 2>/dev/null; then
    echo "CONFIG_TARGET_rockchip_rk35xx_DEVICE_roceos_k50s=y" >> .config
elif grep -q "CONFIG_TARGET_rockchip_armv8=y" .config 2>/dev/null; then
    echo "CONFIG_TARGET_rockchip_armv8_DEVICE_roceos_k50s=y" >> .config
else
    # 若 .config 未初始化，默认设为 rk35xx
    echo "CONFIG_TARGET_rockchip=y" >> .config
    echo "CONFIG_TARGET_rockchip_rk35xx=y" >> .config
    echo "CONFIG_TARGET_rockchip_rk35xx_DEVICE_roceos_k50s=y" >> .config
fi

# ---- 5. 同步配置并验证 ----
make defconfig

# 验证 K50S 是否被选中
if grep -q "DEVICE_roceos_k50s=y" .config; then
    echo ">>> K50S 已成功注册到构建系统"
else
    echo ">>> 警告：K50S 可能未正确注册，请检查 .config"
fi
