/**
 * SignalFieldCanvas.ets — 方向 B「局域网信号场」Canvas 动画组件
 *
 * 完整移植 design-demos/dir-2.html 的 LanScene：
 *  · 径向渐变满版场景 + 三层同心环
 *  · 从本机向外扩散的 3 条涟漪（4.2s 循环，错峰 1.4s）
 *  · 本机到每台设备的二次贝塞尔弧线 + 虚线流动（lineDashOffset）
 *  · 沿弧线循环流动的高亮光点
 *  · 本机节点（多层光晕）、设备节点（选中态脉冲环 + 名称/类型标签）
 *
 * 30fps 定时器直接操作 CanvasRenderingContext2D 重绘，不触发 build。
 * 每帧读取 AppStorage 的 sceneIsDark，随系统深浅色自动切换色板。
 * 设备节点由外部按归一化坐标(0~1)传入，点击回调命中检测。
 */

import { ScenePalette, SceneMotion, SceneNode, scenePalette, isSceneDark } from '../../common/SceneTokens';

@ComponentV2
export struct SignalFieldCanvas {
  /** 设备节点（归一化坐标 0~1），数组引用变化即刷新绘制内容。 */
  @Param nodes: SceneNode[] = []
  /** 点击设备节点回调（传节点 id）。 */
  @Event onSelectNode: (id: string) => void = (_id: string) => {}

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D()
  private canvasWidth: number = 0
  private canvasHeight: number = 0
  private timerId: number = -1
  private startTime: number = 0

  aboutToAppear(): void {
    this.startTime = Date.now()
    this.timerId = setInterval(() => {
      this.drawField()
    }, 33)
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /** 二次贝塞尔曲线上的点：B(t) = (1-t)^2 P0 + 2(1-t)t P1 + t^2 P2。 */
  private quadPoint(p0: number, p1: number, p2: number, t: number): number {
    let u: number = 1 - t
    return u * u * p0 + 2 * u * t * p1 + t * t * p2
  }

  /**
   * 将场景色板色值（6 位 #RRGGBB 或 8 位 #AARRGGBB）转换为 Canvas 可用的 rgba()。
   * 8 位按 ArkUI 约定高位为 alpha，取后 6 位作 RGB；alpha 由参数显式覆盖。
   */
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

  private drawField(): void {
    let w: number = this.canvasWidth
    let h: number = this.canvasHeight
    if (w <= 0 || h <= 0) {
      return
    }
    let ctx: CanvasRenderingContext2D = this.context
    let pal: ScenePalette = scenePalette(isSceneDark())
    let elapsed: number = Date.now() - this.startTime

    // 清屏
    ctx.clearRect(0, 0, w, h)

    // ① 径向渐变场景：中心高光 → 中段 → 深底
    let bg = ctx.createRadialGradient(w * 0.5, h * 0.42, 0, w * 0.5, h * 0.42, Math.max(w, h) * 0.78)
    bg.addColorStop(0, pal.deep3)
    bg.addColorStop(0.42, pal.deep2)
    bg.addColorStop(0.78, pal.deep)
    bg.addColorStop(1, pal.base)
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, w, h)

    // 本机中心
    let cx: number = w * 0.5
    let cy: number = h * 0.56
    // 放大系数：分母越小动画元素越大。420vp 高画布下元素明显放大。
    let scale: number = Math.min(w, h) / 620

    // ② 中心柔光晕
    let halo = ctx.createRadialGradient(cx, cy, 0, cx, cy, 212 * scale)
    halo.addColorStop(0, this.css(pal.haloIn, 0.4))
    halo.addColorStop(0.55, this.css(pal.haloMid, 0.13))
    halo.addColorStop(1, this.css(pal.haloMid, 0))
    ctx.fillStyle = halo
    ctx.beginPath()
    ctx.arc(cx, cy, 212 * scale, 0, Math.PI * 2)
    ctx.fill()

    // ③ 三层同心环
    ctx.lineWidth = 1
    let ringAlphas: number[] = [0.11, 0.08, 0.05]
    for (let i = 0; i < 3; i++) {
      let r = [72, 124, 178][i] * scale
      ctx.strokeStyle = this.css(pal.ripple, ringAlphas[i])
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, Math.PI * 2)
      ctx.stroke()
    }

    // ④ 三条从中心向外扩散的涟漪
    for (let k = 0; k < 3; k++) {
      let phase = ((elapsed + k * SceneMotion.RIPPLE_STAGGER) % SceneMotion.RIPPLE_DURATION) /
        SceneMotion.RIPPLE_DURATION
      let r = (26 + phase * (152 - 26)) * scale
      let opacity = 0.52 * (1 - phase)
      ctx.strokeStyle = this.css(pal.ripple, opacity)
      ctx.lineWidth = 1.3
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, Math.PI * 2)
      ctx.stroke()
    }

    // ⑤ 设备节点：弧线 + 流动光点 + 节点本体
    let nodes: SceneNode[] = this.nodes
    for (let i = 0; i < nodes.length; i++) {
      let node: SceneNode = nodes[i]
      let nx: number = cx + (node.x - 0.5) * w
      let ny: number = cy + (node.y - 0.563) * h
      let dx: number = nx - cx
      let dy: number = ny - cy
      // 控制点：中点沿法线偏移，形成柔光弧
      let midX: number = (cx + nx) / 2
      let midY: number = (cy + ny) / 2
      let ctrlX: number = midX - dy * 0.28
      let ctrlY: number = midY + dx * 0.28

      // 弧线渐变：近本机端淡 → 设备端亮
      let arc = ctx.createLinearGradient(cx, cy, nx, ny)
      arc.addColorStop(0, this.css(pal.accent, 0.10))
      arc.addColorStop(0.68, this.css(pal.accentText, 0.72))
      arc.addColorStop(1, this.css(pal.glowStrong, 0.96))
      ctx.strokeStyle = arc
      ctx.lineWidth = node.selected ? 2.4 : 1.4
      ctx.lineCap = 'round'
      ctx.setLineDash([5, 7])
      ctx.lineDashOffset = -(elapsed / SceneMotion.ARC_DASH) * 24
      ctx.beginPath()
      ctx.moveTo(cx, cy)
      ctx.quadraticCurveTo(ctrlX, ctrlY, nx, ny)
      ctx.stroke()
      ctx.setLineDash([])

      // 沿弧线流动的光点
      let ft: number = ((elapsed % (SceneMotion.FLOW_DURATION + i * 260)) /
        (SceneMotion.FLOW_DURATION + i * 260))
      let px: number = this.quadPoint(cx, ctrlX, nx, ft)
      let py: number = this.quadPoint(cy, ctrlY, ny, ft)
      ctx.fillStyle = pal.arcPoint
      ctx.shadowColor = pal.glow
      ctx.shadowBlur = 10
      ctx.beginPath()
      ctx.arc(px, py, (node.selected ? 3.6 : 2.6) * Math.max(scale, 0.7), 0, Math.PI * 2)
      ctx.fill()
      ctx.shadowBlur = 0

      // 选中态脉冲环
      if (node.selected) {
        let pulse = 0.5 + 0.5 * Math.sin((elapsed / 2600) * Math.PI * 2)
        let pr = (16 + pulse * 12) * Math.max(scale, 0.7)
        ctx.strokeStyle = this.css(pal.glow, 0.9 - pulse * 0.7)
        ctx.lineWidth = 1.4
        ctx.beginPath()
        ctx.arc(nx, ny, pr, 0, Math.PI * 2)
        ctx.stroke()
      }

      // 设备光晕
      let glow = ctx.createRadialGradient(nx, ny, 0, nx, ny, 15 * Math.max(scale, 0.7))
      glow.addColorStop(0, this.css(pal.accentText, node.selected ? 0.5 : 0.26))
      glow.addColorStop(1, this.css(pal.accentText, 0))
      ctx.fillStyle = glow
      ctx.beginPath()
      ctx.arc(nx, ny, 15 * Math.max(scale, 0.7), 0, Math.PI * 2)
      ctx.fill()

      // 设备圆点（放大）
      ctx.fillStyle = node.selected ? pal.white : (isSceneDark() ? '#BBD9F7' : pal.accent)
      ctx.beginPath()
      ctx.arc(nx, ny, (node.selected ? 8 : 6) * Math.max(scale, 0.7), 0, Math.PI * 2)
      ctx.fill()

      // 名称 + 类型标签（放大字号）
      ctx.textAlign = 'center'
      ctx.font = `${node.selected ? 700 : 500} ${Math.round(17 * Math.max(scale, 0.85))}px sans-serif`
      ctx.fillStyle = node.selected ? pal.primary : this.css(pal.primary, 0.78)
      ctx.fillText(node.name, nx, ny - 24 * Math.max(scale, 0.85))
      ctx.font = `${Math.round(14 * Math.max(scale, 0.85))}px sans-serif`
      ctx.fillStyle = this.css(pal.primary, 0.72)
      ctx.fillText(node.kind, nx, ny + 30 * Math.max(scale, 0.85))
    }

    // ⑥ 本机节点（多层）
    let sr = Math.max(scale, 0.7)
    let selfGlow = ctx.createRadialGradient(cx, cy, 0, cx, cy, 22 * sr)
    selfGlow.addColorStop(0, this.css(pal.accentText, 0.35))
    selfGlow.addColorStop(1, this.css(pal.accentText, 0))
    ctx.fillStyle = selfGlow
    ctx.beginPath()
    ctx.arc(cx, cy, 22 * sr, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = isSceneDark() ? '#EAF6FF' : pal.accent
    ctx.beginPath()
    ctx.arc(cx, cy, 9 * sr, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = pal.arcPoint
    ctx.beginPath()
    ctx.arc(cx, cy, 3.8 * sr, 0, Math.PI * 2)
    ctx.fill()
    // 本机标签使用固定默认字号，不随画布缩放变化（系统默认正文大小）
    ctx.font = '14px sans-serif'
    ctx.fillStyle = this.css(pal.primary, 0.72)
    ctx.textAlign = 'center'
    ctx.fillText('本机', cx, cy + 34)
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.drawField()
      })
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.canvasWidth = newValue.width as number
        this.canvasHeight = newValue.height as number
        this.drawField()
      })
      .onTouch((event: TouchEvent) => {
        if (event.type !== TouchType.Down || event.touches.length === 0) {
          return
        }
        // TouchObject 坐标是相对组件的 vp 坐标，与 Canvas 绘制坐标同坐标系
        let x: number = event.touches[0].x
        let y: number = event.touches[0].y
        let cx: number = this.canvasWidth * 0.5
        let cy: number = this.canvasHeight * 0.56
        // 命中半径 36vp（与原型一致）
        for (let i = 0; i < this.nodes.length; i++) {
          let node: SceneNode = this.nodes[i]
          let nx: number = cx + (node.x - 0.5) * this.canvasWidth
          let ny: number = cy + (node.y - 0.563) * this.canvasHeight
          let dx: number = x - nx
          let dy: number = y - ny
          if (dx * dx + dy * dy <= 36 * 36) {
            this.onSelectNode(node.id)
            return
          }
        }
      })
  }
}
