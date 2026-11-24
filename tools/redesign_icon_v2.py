# -*- coding: utf-8 -*-
"""
鸿蒙分享(HarmonyShare) 应用图标 v2 —— 对齐方向B「深蓝信号场」
分层 1024×1024，遵循 HarmonyOS NEXT 新拟态双层规范：
  背景层 background.png：深蓝纵向渐变(顶部受光、由浅到深) + 同心涟漪信号场 + 顶部柔光 + 右下辉光，完全不透明(无 alpha)
  前景层 foreground.png：白色折面纸飞机(分享/发送语义) + 流动光点尾迹，主体落在安全区内(半径<312px)，透明背景

设计要点：
  - 单一主导元素：纸飞机
  - 方向B色板：#050912 底 / #1E3A63 受光 / #2779C6 accent / #8CC8FF glow / #C4E4FF 高光
  - 不预切圆角(系统蒙版处理)，背景无透明像素
  - 4 倍超采样后 LANCZOS 缩放，边缘平滑
"""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 4                 # 超采样倍率
SZ = 1024 * S         # 超采样画布
OUT = r"C:\HUAWEI\WorkBuddy\2026-11-22-09-53-05\HandySend\AppScope\resources\base\media"
PREVIEW = r"C:\HUAWEI\WorkBuddy\2026-11-22-09-53-05\output"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def build_background():
    """背景层：深蓝纵向渐变(顶部受光) + 涟漪信号场，完全不透明。"""
    # 1) 低分辨率纵向渐变后放大(避免 4096² 逐像素慢循环)
    small = 256
    g = Image.new("RGB", (small, small))
    px = g.load()
    top = (30, 58, 99)     # 顶部受光 #1E3A63
    mid = (14, 31, 58)     # 中部 #0E1F3A
    bot = (5, 9, 18)       # 底部深 #050912
    for y in range(small):
        t = y / (small - 1)
        c = lerp(top, mid, t / 0.55) if t < 0.55 else lerp(mid, bot, (t - 0.55) / 0.45)
        for x in range(small):
            px[x, y] = c
    bg = g.resize((SZ, SZ), Image.LANCZOS).convert("RGBA")

    # 2) 顶部柔光(顶部受光的高光)
    glow = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = int(SZ * 0.5), int(SZ * 0.02)
    r0 = int(SZ * 0.66)
    for i in range(64, 0, -1):
        r = int(r0 * i / 64)
        a = int(22 * (1 - i / 64) + 1)
        gd.ellipse([cx - r, cy - r * 0.5, cx + r, cy + r * 0.5], fill=(190, 222, 255, a))
    glow = glow.filter(ImageFilter.GaussianBlur(SZ // 48))
    bg = Image.alpha_composite(bg, glow)

    # 3) 同心涟漪信号场(方向B核心隐喻)，圆心略偏下，淡雅但清晰可辨
    rip = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rip)
    ccx, ccy = SZ // 2, int(SZ * 0.56)
    for radius, width, alpha in [(150, 3, 52), (268, 3, 38), (392, 4, 27), (525, 5, 18)]:
        r = radius * S
        rd.ellipse([ccx - r, ccy - r, ccx + r, ccy + r],
                   outline=(150, 205, 255, alpha), width=width * S)
    rip = rip.filter(ImageFilter.GaussianBlur(SZ // 500))
    bg = Image.alpha_composite(bg, rip)

    # 3b) 中心信号源极淡辉光(涟漪从此扩散)
    core = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    cr = int(SZ * 0.24)
    for i in range(32, 0, -1):
        r = int(cr * i / 32)
        a = int(16 * (1 - i / 32) + 1)
        cd.ellipse([ccx - r, ccy - r, ccx + r, ccy + r], fill=(120, 180, 255, a))
    core = core.filter(ImageFilter.GaussianBlur(SZ // 70))
    bg = Image.alpha_composite(bg, core)

    # 4) 右下辉光装饰(新拟态通透层次)
    deco = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco)
    ccx, ccy, rr = int(SZ * 0.94), int(SZ * 0.99), int(SZ * 0.46)
    for i in range(40, 0, -1):
        r = int(rr * i / 40)
        a = int(18 * (1 - i / 40) + 1)
        dd.ellipse([ccx - r, ccy - r, ccx + r, ccy + r], fill=(90, 152, 240, a))
    deco = deco.filter(ImageFilter.GaussianBlur(SZ // 62))
    bg = Image.alpha_composite(bg, deco)

    # 保存为 RGB(无 alpha 通道) → 保证背景层完全不透明，符合上架校验
    bg.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(OUT + r"\background.png")
    print("background.png done (RGB, fully opaque)")


def build_foreground():
    """前景层：粗描边空心纸飞机(机头右上/左翼尖/V形燕尾/内部折痕)，透明背景。

    直接从用户提供的参考线稿 tools/plane_ref.png 描摹：
    提取黑色线条→反相为白色描边(alpha 来自亮度差)，按安全区缩放居中。
    """
    ref = Image.open(r"C:\HUAWEI\WorkBuddy\2026-11-22-09-53-05\HandySend\tools\plane_ref.png").convert("RGB")
    lum = ref.convert("L")
    # 参考底为亮度~240浅色、线条为纯黑0；用 128 阈值分离，
    # 仅<128 的暗像素(线条+抗锯齿边)转为 alpha，背景(>200)完全排除
    alpha = lum.point(lambda v: max(0, min(255, int((128 - v) / 96 * 255))))
    bbox = alpha.getbbox()
    alpha = alpha.crop(bbox)
    cw, ch = alpha.size

    # 白描边小图
    stroke = Image.new("RGBA", (cw, ch), (255, 255, 255, 0))
    stroke.putalpha(alpha)

    # 计算内容到中心的最大半径，缩放到安全区目标(半边 58% < 66dp 的 61.1%)
    cx, cy = cw / 2.0, ch / 2.0
    ap = alpha.load()
    max_r = 0
    for y in range(ch):
        for x in range(cw):
            if ap[x, y] > 8:
                d = math.hypot(x - cx, y - cy)
                if d > max_r:
                    max_r = d
    scale = (512 * 0.58) / max_r   # 目标半径 = 半边(512)的 58% < 66dp 的 61.1%
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    stroke_big = stroke.resize((nw, nh), Image.LANCZOS)

    fg = Image.new("RGBA", (S * 1024, S * 1024), (0, 0, 0, 0))
    fg.paste(stroke_big.resize((nw * S, nh * S), Image.LANCZOS),
             ((S * 1024 - nw * S) // 2, (S * 1024 - nh * S) // 2))

    # 新拟态柔光：描边外扩一层极淡蓝白光晕，让白线从深蓝底浮出
    glow = fg.filter(ImageFilter.GaussianBlur(S * 14))
    ga = glow.getchannel("A").point(lambda v: int(v * 0.30))
    glow.putalpha(ga)
    fg = Image.alpha_composite(glow, fg)

    fg.resize((1024, 1024), Image.LANCZOS).save(OUT + r"\foreground.png")
    print("foreground.png done (RGBA, transparent, outline paper plane)")


def build_preview():
    """合成预览：方形 / 圆形蒙版 / 小尺寸可辨识度，便于确认效果。"""
    bg = Image.open(OUT + r"\background.png").convert("RGBA")
    fg = Image.open(OUT + r"\foreground.png").convert("RGBA")
    comp = Image.alpha_composite(bg, fg)

    # 圆形蒙版(模拟桌面图标)
    mask = Image.new("L", (1024, 1024), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, 1023, 1023], fill=255)
    circle = comp.copy()
    circle.putalpha(mask)

    canvas = Image.new("RGB", (1200, 470), (238, 240, 244))
    dc = ImageDraw.Draw(canvas)

    # 方形合成
    sq = comp.resize((420, 420), Image.LANCZOS)
    canvas.paste(sq, (20, 30), sq)
    dc.text((20, 8), "Square (flat)", fill=(40, 50, 70))

    # 圆形蒙版
    ci = circle.resize((420, 420), Image.LANCZOS)
    canvas.paste(ci, (430, 30), ci)
    dc.text((430, 8), "Circle mask (desktop)", fill=(40, 50, 70))

    # 小尺寸可辨识度(96 / 48 放大展示)
    s96 = comp.resize((96, 96), Image.LANCZOS).resize((240, 240), Image.NEAREST)
    s48 = comp.resize((48, 48), Image.LANCZOS).resize((240, 240), Image.NEAREST)
    canvas.paste(s96, (860, 30))
    canvas.paste(s48, (860, 260))
    dc.text((860, 8), "96px (zoom)", fill=(40, 50, 70))
    dc.text((860, 238), "48px (zoom)", fill=(40, 50, 70))

    canvas.save(PREVIEW + r"\icon_preview_v2.png")
    print("icon_preview_v2.png done")


if __name__ == "__main__":
    build_background()
    build_foreground()
    build_preview()
