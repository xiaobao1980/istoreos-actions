#!/bin/bash
#============================================================
# iStoreOS 云编译 DIY 脚本 Part2
# 支持：istoreos-22.03 (rk35xx) / istoreos-24.10 (armv8)
# 设备：ROCEOS K50S (RK3568)
#============================================================

set -e

echo "============================================"
echo "  DIY Part2 开始执行"
echo "  分支参数: $1 / $2"
echo "  工作目录: $(pwd)"
echo "============================================"

# ==========================================
# 通用设置
# ==========================================
# 设置编译时区
export TZ=Asia/Shanghai

# ==========================================
# 22.03 分支 (rk35xx)
# ==========================================
if [ "$1" = "istoreos-22.03" ] || [ "$2" = "rk35xx" ]; then
    echo "===== 配置 22.03 / rk35xx ====="

    # 加载 22.03 的 .config
    if [ -f "$GITHUB_WORKSPACE/rk35xx/.config" ]; then
        cat "$GITHUB_WORKSPACE/rk35xx/.config" > .config
        echo "已加载 rk35xx/.config"
    else
        echo "警告: 未找到 rk35xx/.config，使用默认配置"
    fi

    # 添加 K50S 设备支持
    if [ -f "$GITHUB_WORKSPACE/scripts/add-device.sh" ]; then
        chmod +x "$GITHUB_WORKSPACE/scripts/add-device.sh"
        "$GITHUB_WORKSPACE/scripts/add-device.sh" "$1" "$2"
    else
        echo "警告: add-device.sh 不存在"
    fi

    # 确保 .config 中包含 K50S（22.03 格式为 rk35xx）
    if ! grep -q "CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_roceos_k50s=y" .config; then
        echo "CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_roceos_k50s=y" >> .config
        echo "已追加 K50S 配置 (rk35xx)"
    fi

    # 重新生成配置
    make defconfig

    # 验证 K50S 是否保留
    if grep -q "CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_roceos_k50s=y" .config; then
        echo "✅ 22.03 K50S 设备配置已确认"
    else
        echo "❌ 22.03 K50S 设备配置丢失，检查 add-device.sh 和 armv8.mk/rk35xx.mk"
        exit 1
    fi

# ==========================================
# 24.10 分支 (armv8)
# ==========================================
elif [ "$1" = "istoreos-24.10" ] || [ "$2" = "rk35xx-24.10" ]; then
    echo "===== 配置 24.10 / rk35xx-24.10 ====="

    # 加载 24.10 的 .config
    if [ -f "$GITHUB_WORKSPACE/rk35xx-24.10/.config" ]; then
        cat "$GITHUB_WORKSPACE/rk35xx-24.10/.config" > .config
        echo "已加载 rk35xx-24.10/.config"
    else
        echo "警告: 未找到 rk35xx-24.10/.config，使用默认配置"
    fi

    # 添加 K50S 设备支持
    if [ -f "$GITHUB_WORKSPACE/scripts/add-device.sh" ]; then
        chmod +x "$GITHUB_WORKSPACE/scripts/add-device.sh"
        "$GITHUB_WORKSPACE/scripts/add-device.sh" "$1" "$2"
    else
        echo "警告: add-device.sh 不存在"
    fi

    # 确保 .config 中包含 K50S（24.10 格式为 armv8）
    # 先删除可能存在的旧格式（防止重复或冲突）
    sed -i '/CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_roceos_k50s/d' .config
    sed -i '/CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_roceos_k50s/d' .config
    echo "CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_roceos_k50s=y" >> .config
    echo "已追加 K50S 配置 (armv8)"

    # 重新生成配置
    make defconfig

    # 验证 K50S 是否保留
    if grep -q "CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_roceos_k50s=y" .config; then
        echo "✅ 24.10 K50S 设备配置已确认"
    else
        echo "❌ 24.10 K50S 设备配置丢失，检查 add-device.sh 和 armv8.mk"
        echo "===== armv8.mk 末尾 20 行 ====="
        tail -20 "target/linux/rockchip/image/armv8.mk" || true
        exit 1
    fi

else
    echo "警告: 未匹配到已知分支 ($1 / $2)"
    exit 1
fi

# ==========================================
# 通用编译优化（可选）
# ==========================================
# 启用 ccache
# echo "CONFIG_CCACHE=y" >> .config

# 替换主题（可选）
# rm -rf feeds/luci/themes/luci-theme-argon
# git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git feeds/luci/themes/luci-theme-argon

echo "============================================"
echo "  DIY Part2 执行完成"
echo "============================================"
