# -*- coding: utf-8 -*-
"""HandySend(鸿蒙分享) 应用图标重绘：分层图标 1024x1024
背景层：宇宙蓝对角渐变(HarmonyOS 品牌蓝 #0A59F7) + 柔和高光，无透明像素
前景层：白色纸飞机(发送语义) + 动势短线，主体位于中心安全区(半径约350px)，透明背景
以 4 倍超采样绘制后缩至 1024，保证边缘平滑。
"""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 4            # 超采样倍率
SZ = 1024 * S    # 画布
OUT = r"C:\HUAWEI\WorkBuddy\2026-11-22-09-53-05\HandySend\AppScope\resources\base\media"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_background():
    img = Image.new("RGB", (SZ, SZ))
    c_tl = (74, 140, 255)    # 左上亮蓝
    c_mid = (10, 89, 247)    # 品牌宇宙蓝
    c_br = (6, 55, 168)      # 右下深蓝
    px = img.load()
    # 对角渐变
    for y in range(SZ):
        for x in range(0, SZ, 1):
            t = (x + y) / (2 * SZ)
            if t < 0.55:
                px[x, y] = lerp(c_tl, c_mid, t / 0.55)
            else:
                px[x, y] = lerp(c_mid, c_br, (t - 0.55) / 0.45)
    # 顶部柔光(叠层椭圆，逐层降透明度)
    glow = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, r0 = int(SZ * 0.30), int(SZ * 0.22), int(SZ * 0.75)
    steps = 48
    for i in range(steps, 0, -1):
        r = int(r0 * i / steps)
        a = int(26 * (1 - i / steps) + 2)
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, a))
    glow = glow.filter(ImageFilter.GaussianBlur(SZ // 40))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    # 右下装饰大圆(半透明，丰富层次)
    deco = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco)
    for (ccx, ccy, rr, aa) in [(SZ * 0.95, SZ * 0.98, SZ * 0.52, 22), (SZ * 0.72, SZ * 1.05, SZ * 0.36, 16)]:
        dd.ellipse([ccx - rr, ccy - rr, ccx + rr, ccy + rr], fill=(255, 255, 255, aa))
    deco = deco.filter(ImageFilter.GaussianBlur(SZ // 90))
    img = Image.alpha_composite(img, deco)
    img.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(OUT + r"\background.png")
    print("background.png done")


def draw_foreground():
    layer = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # 实心纸飞机：完整三角机身保证轮廓连贯，尾部折面浅蓝色块表现纸张折叠层次
    s = 25 * S
    ox = 512 * S - 12.75 * s
    oy = 512 * S - 12.0 * s

    def P(x, y):
        return (ox + x * s, oy + y * s)

    d.polygon([P(2, 2), P(23.5, 12), P(2, 22)], fill=(255, 255, 255, 255))
    d.polygon([P(2, 2), P(4.8, 12), P(2, 22)], fill=(191, 214, 255, 255))  # 尾部薄折边
    # 整体旋转 -12 度增加动势
    layer = layer.rotate(-12, resample=Image.BICUBIC, center=(512 * S, 512 * S))
    layer.resize((1024, 1024), Image.LANCZOS).save(OUT + r"\foreground.png")
    print("foreground.png done")


draw_background()
draw_foreground()

# 预览合成图(圆形遮罩效果)：给用户直观预览
bg = Image.open(OUT + r"\background.png").convert("RGBA")
fg = Image.open(OUT + r"\foreground.png").convert("RGBA")
comp = Image.alpha_composite(bg, fg)
comp.save(r"C:\HUAWEI\WorkBuddy\2026-11-22-09-53-05\output\icon_preview.png")
print("preview saved")
