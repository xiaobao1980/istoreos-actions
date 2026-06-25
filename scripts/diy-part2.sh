#!/bin/bash
# scripts/diy-part2.sh —— 云编译注入 ROCEOS K50S 设备

set -e
echo "========== Injecting ROCEOS K50S =========="

# -------------------------------------------------
# 1. 在 armv8.mk 中定义设备
# -------------------------------------------------
ARMV8_MK="target/linux/rockchip/image/armv8.mk"

if ! grep -q "roceos_k50s" "$ARMV8_MK"; then
    cat >> "$ARMV8_MK" << 'EOF'

define Device/roceos_k50s
  DEVICE_VENDOR := ROCEOS
  DEVICE_MODEL := K50S
  SOC := rk3568
  DEVICE_DTS := rk3568-roceos-k50s
  DEVICE_PACKAGES := kmod-r8125 kmod-phy-realtek
  SUPPORTED_DEVICES += roceos,k50s
endef
TARGET_DEVICES += roceos_k50s
EOF
    echo "[OK] Added device to armv8.mk"
else
    echo "[SKIP] Device already in armv8.mk"
fi

# -------------------------------------------------
# 2. 创建 DTS 设备树（RK3568 + 2xGMAC + 3xPCIe RTL8125）
# -------------------------------------------------
DTS_DIR="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
DTS_FILE="$DTS_DIR/rk3568-roceos-k50s.dts"
mkdir -p "$DTS_DIR"

cat > "$DTS_FILE" << 'EOF'
// SPDX-License-Identifier: (GPL-2.0+ OR MIT)
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

&uart2 {
	pinctrl-names = "default";
	pinctrl-0 = <&uart2m0_xfer>;
	status = "okay";
};

&sdmmc0 {
	bus-width = <4>;
	cap-sd-highspeed;
	cap-mmc-highspeed;
	disable-wp;
	no-sdio;
	pinctrl-names = "default";
	pinctrl-0 = <&sdmmc0_bus4 &sdmmc0_clk &sdmmc0_cmd>;
	status = "okay";
};

&sdhci {
	bus-width = <8>;
	mmc-hs200-1_8v;
	non-removable;
	disable-wp;
	no-sd;
	no-sdio;
	pinctrl-names = "default";
	pinctrl-0 = <&emmc_bus8 &emmc_clk &emmc_cmd>;
	status = "okay";
};

&gmac0 {
	phy-mode = "rgmii";
	clock_in_out = "phy";
	snps,reset-gpio = <&gpio0 RK_PB7 GPIO_ACTIVE_LOW>;
	snps,reset-delays-us = <0 10000 50000>;
	assigned-clocks = <&cru SCLK_GMAC0_RX_TX>, <&cru SCLK_GMAC0>;
	assigned-clock-rates = <0>, <125000000>;
	pinctrl-names = "default";
	pinctrl-0 = <&gmac0_miim &gmac0_tx_bus2 &gmac0_rx_bus2 &gmac0_rgmii_clk &gmac0_rgmii_bus>;
	tx_delay = <0x3c>;
	rx_delay = <0x2f>;
	status = "okay";
};

&gmac1 {
	phy-mode = "rgmii";
	clock_in_out = "phy";
	snps,reset-gpio = <&gpio1 RK_PB0 GPIO_ACTIVE_LOW>;
	snps,reset-delays-us = <0 10000 50000>;
	assigned-clocks = <&cru SCLK_GMAC1_RX_TX>, <&cru SCLK_GMAC1>;
	assigned-clock-rates = <0>, <125000000>;
	pinctrl-names = "default";
	pinctrl-0 = <&gmac1m1_miim &gmac1m1_tx_bus2 &gmac1m1_rx_bus2 &gmac1m1_rgmii_clk &gmac1m1_rgmii_bus>;
	tx_delay = <0x4f>;
	rx_delay = <0x26>;
	status = "okay";
};

&pcie2x1 {
	reset-gpios = <&gpio0 RK_PC6 GPIO_ACTIVE_HIGH>;
	status = "okay";
};

&pcie3x1 {
	reset-gpios = <&gpio0 RK_PC7 GPIO_ACTIVE_HIGH>;
	status = "okay";
};

&pcie3x2 {
	reset-gpios = <&gpio1 RK_PA0 GPIO_ACTIVE_HIGH>;
	status = "okay";
};

&usb2phy0 { status = "okay"; };
&usb2phy1 { status = "okay"; };
&usb2phy2 { status = "okay"; };
&usb2phy3 { status = "okay"; };
&u2phy0 { status = "okay"; };
&u2phy1 { status = "okay"; };
&u2phy2 { status = "okay"; };
&u2phy3 { status = "okay"; };
&usb_host0_xhci { status = "okay"; };
&usb_host1_xhci { status = "okay"; };
EOF

echo "[OK] Created DTS"

# -------------------------------------------------
# 3. 修改 02_network 设置网口（4 LAN + 1 WAN）
# -------------------------------------------------
BOARD_D="target/linux/rockchip/base-files/etc/board.d/02_network"

if ! grep -q "roceos,k50s" "$BOARD_D"; then
    # 用 awk 在最后一个 esac 前安全插入
    awk '/^esac/ && !done {
        print "roceos,k50s)"
        print "\tucidef_set_interfaces_lan_wan \"eth0 eth1 eth2 eth3\" \"eth4\""
        print "\t;;"
        done=1
    } {print}' "$BOARD_D" > "${BOARD_D}.tmp"
    mv "${BOARD_D}.tmp" "$BOARD_D"
    chmod +x "$BOARD_D"
    echo "[OK] Added network config to 02_network"
else
    echo "[SKIP] Network config already present"
fi

# -------------------------------------------------
# 4. 强制 .config 选中该设备（双重保险）
# -------------------------------------------------
# 如果仓库里有 .config，追加设备配置
if [ -f ".config" ]; then
    if ! grep -q "CONFIG_TARGET_rockchip_armv8_DEVICE_roceos_k50s=y" ".config"; then
        echo "CONFIG_TARGET_rockchip_armv8_DEVICE_roceos_k50s=y" >> .config
        echo "[OK] Appended device to .config"
    fi
else
    # 如果没有 .config，创建一个最小配置片段
    echo "CONFIG_TARGET_rockchip_armv8_DEVICE_roceos_k50s=y" >> .config
    echo "CONFIG_PACKAGE_kmod-r8125=y" >> .config
    echo "[OK] Created minimal .config"
fi

# -------------------------------------------------
# 5. 验证（在 Actions 日志中查看）
# -------------------------------------------------
echo ""
echo "========== Verification =========="
grep -c "roceos_k50s" "$ARMV8_MK" && echo "[PASS] armv8.mk" || echo "[FAIL] armv8.mk"
test -f "$DTS_FILE" && echo "[PASS] DTS file" || echo "[FAIL] DTS file"
grep -c "roceos,k50s" "$BOARD_D" && echo "[PASS] 02_network" || echo "[FAIL] 02_network"
grep -c "roceos_k50s" ".config" && echo "[PASS] .config" || echo "[FAIL] .config"
echo "=================================="
