/**
 * SceneKit.ets — 方向 B 通用视觉组件
 *
 * 提供：玻璃卡容器、柔光弧进度线、呼吸状态点、渐变胶囊按钮、场景分组卡。
 * V2 组件用 watchSceneTheme 轮询同步昼/夜色板（@StorageProp 不支持 @ComponentV2）。
 */

import {
  ScenePalette, SceneMotion, scenePalette, isSceneDark, watchSceneTheme, stopSceneThemeWatch
} from '../../common/SceneTokens';

/**
 * 玻璃卡：135° 半透明白渐变 + 24vp 背景模糊，无描边、无阴影。
 * 高度由内容决定（不设 height('100%')，避免撑满父容器盖住信号场）。
 */
@ComponentV2
export struct GlassCard {
  @Param cardRadius: number = 22
  @Param cardPadding: number = 18
  @Local sceneIsDark: boolean = false
  @BuilderParam content: () => void

  private themeTimer: number = -1

  aboutToAppear(): void {
    this.sceneIsDark = isSceneDark()
    this.themeTimer = watchSceneTheme((dark: boolean) => { this.sceneIsDark = dark })
  }

  aboutToDisappear(): void {
    stopSceneThemeWatch(this.themeTimer)
  }

  build() {
    Stack() {
      Column() {
        this.content()
      }
      .width('100%')
    }
    .width('100%')
    .borderRadius(this.cardRadius)
    .padding(this.cardPadding)
    .linearGradient({
      angle: 135,
      colors: [
        [scenePalette(this.sceneIsDark).glassTop, 0],
        [scenePalette(this.sceneIsDark).glassBottom, 1]
      ]
    })
    // 不设 backgroundColor：半透明渐变已提供底色，再叠一层半透明 backgroundColor
    // 会让实际 alpha 叠加升高（接近实底），且部分系统版本 backdropBlur 不生效导致像白板。
    // 只保留单层半透明渐变 + blur（支持的设备上生效），真正透出背后动画。
    .backdropBlur(24)
    // 设备卡片：不要描边、不要阴影，保持干净的半透明玻璃质感。
  }
}

/** 呼吸状态点：原型 .live-dot，1.8s 透明度呼吸 + 柔光。 */
@ComponentV2
export struct ScenePulseDot {
  @Param color: string = ''
  @Param dotSize: number = 6
  @Local sceneIsDark: boolean = false
  @Local opacityValue: number = 0.45

  private themeTimer: number = -1

  aboutToAppear(): void {
    this.sceneIsDark = isSceneDark()
    this.themeTimer = watchSceneTheme((dark: boolean) => { this.sceneIsDark = dark })
    this.opacityValue = 0.45
    animateTo({ duration: SceneMotion.PULSE_DURATION, iterations: -1, tempo: 1 }, () => {
      this.opacityValue = 1
    })
  }

  aboutToDisappear(): void {
    stopSceneThemeWatch(this.themeTimer)
  }

  build() {
    Row()
      .width(this.dotSize)
      .height(this.dotSize)
      .borderRadius(this.dotSize / 2)
      .backgroundColor(this.color.length > 0 ? this.color : scenePalette(this.sceneIsDark).glow)
      .opacity(this.opacityValue)
      .shadow({ radius: 10, color: this.color.length > 0 ? this.color : scenePalette(this.sceneIsDark).glow })
  }
}

/** 柔光弧进度线：对应原型 TaskArc，二次贝塞尔轨迹 + 渐进取色 + 端点光点。 */
@ComponentV2
export struct FlowArc {
  /** 0~100 进度。 */
  @Param progress: number = 0
  /** 暗化（已完成/已取消态）。 */
  @Param dim: boolean = false
  @Local sceneIsDark: boolean = false

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D()
  private canvasWidth: number = 0
  private canvasHeight: number = 0
  private themeTimer: number = -1

  aboutToAppear(): void {
    this.sceneIsDark = isSceneDark()
    this.themeTimer = watchSceneTheme((dark: boolean) => {
      this.sceneIsDark = dark
      this.drawArc()
    })
  }

  aboutToDisappear(): void {
    stopSceneThemeWatch(this.themeTimer)
  }

  /** 将色板色值（6/8 位 hex）转换为 Canvas rgba()。 */
  private css(hex: string, alpha: number): string {
    let s: string = hex.replace('#', '')
    let r: number
    let g: number
    let b: number
    if (s.length === 8) {
      r = parseInt(s.substring(2, 4), 16)
      g = parseInt(s.substring(4, 6), 16)
      b = parseInt(s.substring(6, 8), 16)
    } else {
      r = parseInt(s.substring(0, 2), 16)
      g = parseInt(s.substring(2, 4), 16)
      b = parseInt(s.substring(4, 6), 16)
    }
    return `rgba(${r},${g},${b},${alpha.toFixed(3)})`
  }

  private quadPoint(p0: number, p1: number, p2: number, t: number): number {
    let u: number = 1 - t
    return u * u * p0 + 2 * u * t * p1 + t * t * p2
  }

  private drawArc(): void {
    let w: number = this.canvasWidth
    let h: number = this.canvasHeight
    if (w <= 0 || h <= 0) {
      return
    }
    let ctx: CanvasRenderingContext2D = this.context
    let pal: ScenePalette = scenePalette(this.sceneIsDark)
    ctx.clearRect(0, 0, w, h)

    let sx: number = w / 240
    let sy: number = h / 58
    let x0: number = 14 * sx
    let y0: number = 46 * sy
    let x1: number = 120 * sx
    let y1: number = 8 * sy
    let x2: number = 226 * sx
    let y2: number = 46 * sy

    // 轨道
    ctx.strokeStyle = this.css(pal.hairline, this.sceneIsDark ? 0.12 : 0.18)
    ctx.lineWidth = 2
    ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.moveTo(x0, y0)
    ctx.quadraticCurveTo(x1, y1, x2, y2)
    ctx.stroke()

    // 渐变进度
    let t: number = Math.max(0, Math.min(100, this.progress)) / 100
    if (t > 0) {
      let grad = ctx.createLinearGradient(x0, 0, x2, 0)
      grad.addColorStop(0, pal.accent)
      grad.addColorStop(1, pal.glowStrong)
      ctx.strokeStyle = grad
      ctx.globalAlpha = this.dim ? 0.45 : 1
      ctx.lineWidth = 2.6
      let steps: number = 36
      let last: number = Math.max(1, Math.floor(steps * t))
      ctx.beginPath()
      ctx.moveTo(x0, y0)
      for (let i = 1; i <= last; i++) {
        let pt: number = (i / steps)
        let px: number = this.quadPoint(x0, x1, x2, pt)
        let py: number = this.quadPoint(y0, y1, y2, pt)
        ctx.lineTo(px, py)
      }
      ctx.stroke()
      ctx.globalAlpha = 1

      // 端点光点（半径 3vp，不是 42）
      let ex: number = this.quadPoint(x0, x1, x2, t)
      let ey: number = this.quadPoint(y0, y1, y2, t)
      ctx.fillStyle = pal.glow
      ctx.globalAlpha = this.dim ? 0.5 : 1
      ctx.beginPath()
      ctx.arc(ex, ey, 3 * Math.max(sx, 0.7), 0, Math.PI * 2)
      ctx.fill()
      ctx.globalAlpha = 1
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height(58)
      .onReady(() => this.drawArc())
      .onAreaChange((_o: Area, n: Area) => {
        this.canvasWidth = n.width as number
        this.canvasHeight = n.height as number
        this.drawArc()
      })
  }
}

/** 渐变胶囊主按钮：原型 SendPill。 */
@ComponentV2
export struct ScenePillButton {
  @Param label: string = '发送'
  @Param showBrand: boolean = false
  @Param isEnabled: boolean = true
  @Local sceneIsDark: boolean = false
  @Event onClickAction: () => void = () => {}

  private themeTimer: number = -1

  aboutToAppear(): void {
    this.sceneIsDark = isSceneDark()
    this.themeTimer = watchSceneTheme((dark: boolean) => { this.sceneIsDark = dark })
  }

  aboutToDisappear(): void {
    stopSceneThemeWatch(this.themeTimer)
  }

  build() {
    Row({ space: 8 }) {
      if (this.showBrand) {
        Image($r('app.media.foreground'))
          .width(14)
          .height(14)
          .objectFit(ImageFit.Contain)
      }
      Text(this.label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFFFF')
    }
    .height(40)
    .padding({ left: 18, right: 18 })
    .borderRadius(999)
    .linearGradient({
      angle: 135,
      colors: [
        [scenePalette(this.sceneIsDark).accent, 0],
        [scenePalette(this.sceneIsDark).accentText, 1]
      ]
    })
    .shadow({ radius: 22, color: '#6B2779C6', offsetY: 8 })
    .opacity(this.isEnabled ? 1 : 0.5)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
    .onClick(() => {
      if (this.isEnabled) {
        this.onClickAction()
      }
    })
  }
}

/** 场景分组标题：字距感由大写字母 + 小字号实现（对应原型 letterSpacing:1）。 */
@ComponentV2
export struct SceneGroupLabel {
  @Param text: string = ''
  @Local sceneIsDark: boolean = false

  private themeTimer: number = -1

  aboutToAppear(): void {
    this.sceneIsDark = isSceneDark()
    this.themeTimer = watchSceneTheme((dark: boolean) => { this.sceneIsDark = dark })
  }

  aboutToDisappear(): void {
    stopSceneThemeWatch(this.themeTimer)
  }

  build() {
    Text(this.text)
      .fontSize(12)
      .fontColor(scenePalette(this.sceneIsDark).muted)
      .letterSpacing(1)
  }
}
