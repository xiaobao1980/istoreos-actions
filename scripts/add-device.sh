#!/bin/bash
# 添加 ROCEOS K50S 设备到 iStoreOS
# 适用：istoreos-22.03 (rk35xx) 和 istoreos-24.10 (armv8)

set -e

echo "===== 添加 ROCEOS K50S 设备支持 ====="

# 创建 DTS 目录
mkdir -p target/linux/rockchip/dts/rk3568
mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip

# 复制 DTS（优先使用 files 覆盖，兼容双分支）
if [ -f "target/linux/rockchip/dts/rk3568/rk3568-roceos-k50s.dts" ]; then
    cp -f target/linux/rockchip/dts/rk3568/rk3568-roceos-k50s.dts \
        target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
    cp -f target/linux/rockchip/dts/rk3568/rk3568-roceos-k50s.dtsi \
        target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/
    echo "已复制 DTS 到 files 覆盖目录"
fi

# ==========================================
# 22.03 分支 (rk35xx)
# ==========================================
if [ "$1" = "istoreos-22.03" ] || [ "$2" = "rk35xx" ]; then
    echo "检测到 22.03 / rk35xx，使用 rk35xx.mk 方式..."

    RK35XX_MK="target/linux/rockchip/image/rk35xx.mk"
    if [ -f "$RK35XX_MK" ]; then
        if ! grep -q "roceos_k50s" "$RK35XX_MK"; then
            cat >> "$RK35XX_MK" << 'EOF'

define Device/roceos_k50s
$(call Device/rk3568)
  DEVICE_VENDOR := ROCEOS
  DEVICE_MODEL := K50S
  SUPPORTED_DEVICES += roceos,k50s
  DEVICE_PACKAGES := kmod-r8125 kmod-r8169
endef
TARGET_DEVICES += roceos_k50s
EOF
            echo "已追加到 $RK35XX_MK"
        else
            echo "K50S 已存在于 $RK35XX_MK，跳过"
        fi
    fi

    # 02_network (22.03 路径)
    NETWORK_FILE="target/linux/rockchip/rk35xx/base-files/etc/board.d/02_network"
    if [ -f "$NETWORK_FILE" ] && ! grep -q "roceos,k50s" "$NETWORK_FILE"; then
        sed -i '/^esac/i\
    roceos,k50s)\
        ucidef_set_interfaces_lan_wan "eth1 eth2 eth3 eth4" "eth0"\
        ;;' "$NETWORK_FILE"
        echo "已注入 02_network (22.03)"
    fi

    # init.sh (22.03 路径)
    INIT_FILE="target/linux/rockchip/rk35xx/base-files/lib/board/init.sh"
    if [ -f "$INIT_FILE" ] && ! grep -q "roceos,k50s" "$INIT_FILE"; then
        sed -i '/esac/i\
    roceos,k50s)' "$INIT_FILE"
        sed -i '/roceos,k50s)/a\
        model="ROCEOS K50S"' "$INIT_FILE"
        echo "已注入 init.sh (22.03)"
    fi

    # ota.sh (22.03 路径)
    OTA_FILE="target/linux/rockchip/rk35xx/base-files/lib/upgrade/ota.sh"
    if [ -f "$OTA_FILE" ] && ! grep -q "roceos,k50s" "$OTA_FILE"; then
        sed -i '/esac/i\
    roceos,k50s)' "$OTA_FILE"
        sed -i '/roceos,k50s)/a\
        export OTA_URL_BOARD="rk3568/roceos-k50s"' "$OTA_FILE"
        echo "已注入 ota.sh (22.03)"
    fi

# ==========================================
# 24.10 分支 (armv8)
# ==========================================
elif [ "$1" = "istoreos-24.10" ] || [ "$2" = "rk35xx-24.10" ]; then
    echo "检测到 24.10 / armv8，使用 armv8.mk 方式..."

    ARMV8_MK="target/linux/rockchip/image/armv8.mk"
    if [ -f "$ARMV8_MK" ]; then
        if ! grep -q "roceos_k50s" "$ARMV8_MK"; then
            cat >> "$ARMV8_MK" << 'EOF'

define Device/roceos_k50s
  DEVICE_VENDOR := ROCEOS
  DEVICE_MODEL := K50S
  SOC := rk3568
  UBOOT_DEVICE_NAME := generic-rk3568
  DEVICE_PACKAGES := kmod-r8125 kmod-r8169
  SUPPORTED_DEVICES += roceos,k50s
endef
TARGET_DEVICES += roceos_k50s
EOF
            echo "已追加到 $ARMV8_MK"
        else
            echo "K50S 已存在于 $ARMV8_MK，跳过"
        fi
    fi

    # 02_network (24.10 路径：armv8 子目录)
    NETWORK_FILE="target/linux/rockchip/armv8/base-files/etc/board.d/02_network"
    if [ -f "$NETWORK_FILE" ] && ! grep -q "roceos,k50s" "$NETWORK_FILE"; then
        sed -i '/^esac/i\
    roceos,k50s)\
        ucidef_set_interfaces_lan_wan "eth1 eth2 eth3 eth4" "eth0"\
        ;;' "$NETWORK_FILE"
        echo "已注入 02_network (24.10)"
    fi

    # init.sh (24.10 路径：armv8 子目录)
    INIT_FILE="target/linux/rockchip/armv8/base-files/lib/board/init.sh"
    if [ -f "$INIT_FILE" ] && ! grep -q "roceos,k50s" "$INIT_FILE"; then
        sed -i '/esac/i\
    roceos,k50s)' "$INIT_FILE"
        sed -i '/roceos,k50s)/a\
        model="ROCEOS K50S"' "$INIT_FILE"
        echo "已注入 init.sh (24.10)"
    fi

    # ota.sh (24.10 路径：armv8 子目录)
    OTA_FILE="target/linux/rockchip/armv8/base-files/lib/upgrade/ota.sh"
    if [ -f "$OTA_FILE" ] && ! grep -q "roceos,k50s" "$OTA_FILE"; then
        sed -i '/esac/i\
    roceos,k50s)' "$OTA_FILE"
        sed -i '/roceos,k50s)/a\
        export OTA_URL_BOARD="rk3568/roceos-k50s"' "$OTA_FILE"
        echo "已注入 ota.sh (24.10)"
    fi

else
    echo "警告：未匹配到已知分支 ($1 / $2)，跳过设备添加"
    exit 0
fi

echo "===== ROCEOS K50S 设备添加完成 ====="
