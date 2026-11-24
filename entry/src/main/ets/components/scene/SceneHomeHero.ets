/**
 * SceneHomeHero.ets — 方向 B 发送主屏「信号场 Hero」
 *
 * 移植 design-demos/dir-2.html 的 SendPhone：
 *  · 满版局域网信号场（SignalFieldCanvas：涟漪/弧线/流动光点/设备节点）
 *  · 顶部诗性状态：呼吸点 + 「局域网 · 设备发现中」+「附近 N 台设备 / 随时可发」
 *  · 底部玻璃卡：目标设备 / 状态 / 进度 / 内容摘要 / 发送按钮
 *
 * 色板随 watchSceneTheme 轮询在系统深浅色间自动切换。
 * 设备来自真实 SendViewModel（LocalSend + 互传联盟），点击光点切换目标；
 * 发送走外部注入的真实链路（SendContent.sendToSelectedDevice），不新造发送逻辑。
 */

import {
  SceneMotion, SceneNode, scenePalette, isSceneDark, watchSceneTheme, stopSceneThemeWatch
} from '../../common/SceneTokens';
import { SignalFieldCanvas } from './SignalFieldCanvas';
import { ScenePulseDot, ScenePillButton, SceneGroupLabel, GlassCard } from './SceneKit';
import { SendViewModel } from '../../viewmodel/SendViewModel';
import { DeviceItemViewModel } from '../../viewmodel/DeviceItemViewModel';
import { DiscoveredDevice } from '../../model/Types';

/** Hero 与标题栏之间的间距（8vp 网格）。 */
const HERO_TOP_GAP: number = 8

/** 设备卡片左右、下三边留白，保持一致（上边距单独用 HERO_TOP_GAP）。 */
const HERO_EDGE_GAP: number = 16

/** 信号场动画区高度：放大动画画布，玻璃卡叠加在其底部。 */
const SCENE_HEIGHT: number = 420

/** 发送反馈阶段。 */
enum SceneSendPhase {
  ready = 0,
  sending = 1,
  done = 2
}

// 设备节点锚点（归一化坐标）。按设备数顺序取用，最多 6 台。
const NODE_ANCHORS: Array<[number, number]> = [
  [0.80, 0.30],
  [0.85, 0.72],
  [0.18, 0.70],
  [0.20, 0.29],
  [0.50, 0.16],
  [0.52, 0.86]
];

@ComponentV2
export struct SceneHomeHero {
  @Require @Param viewModel: SendViewModel
  /** 附近的真实设备（LocalSend + MTA 合并）。 */
  @Param devices: DeviceItemViewModel[] = []
  /** 点击设备光点切换目标后的回调（供外部同步其他 UI，可选）。 */
  @Event onTargetChanged: (device: DiscoveredDevice | undefined) => void =
    (_device: DiscoveredDevice | undefined) => {}
  /** 真实发送链路：由 SendContent 注入。 */
  @Event onSend: (device: DiscoveredDevice) => void = (_device: DiscoveredDevice) => {}
  /** 打开设备详情。 */
  @Event onInfo: (device: DiscoveredDevice) => void = (_device: DiscoveredDevice) => {}

  @Local sceneIsDark: boolean = false
  @Local selectedId: string = ''
  @Local phase: SceneSendPhase = SceneSendPhase.ready
  @Local progress: number = 0

  private progressTimer: number = -1
  private themeTimer: number = -1

  aboutToAppear(): void {
    this.sceneIsDark = isSceneDark()
    this.themeTimer = watchSceneTheme((dark: boolean) => { this.sceneIsDark = dark })
    if (this.selectedId.length === 0 && this.devices.length > 0) {
      this.selectedId = this.identityOf(this.devices[0])
    }
  }

  aboutToDisappear(): void {
    this.stopProgress()
    stopSceneThemeWatch(this.themeTimer)
  }

  private stopProgress(): void {
    if (this.progressTimer >= 0) {
      clearInterval(this.progressTimer)
      this.progressTimer = -1
    }
  }

  /** 设备稳定身份键：与列表口径一致（MTA 用发送者 ID 优先）。 */
  private identityOf(vm: DeviceItemViewModel): string {
    return vm.identityKey
  }

  /** 把真实设备映射为信号场节点。 */
  private buildNodes(): SceneNode[] {
    let result: SceneNode[] = []
    let count: number = Math.min(this.devices.length, NODE_ANCHORS.length)
    for (let i = 0; i < count; i++) {
      let vm: DeviceItemViewModel = this.devices[i]
      let anchor: [number, number] = NODE_ANCHORS[i]
      result.push({
        id: this.identityOf(vm),
        name: vm.alias,
        kind: this.kindLabel(vm.deviceType),
        x: anchor[0],
        y: anchor[1],
        selected: this.identityOf(vm) === this.selectedId
      })
    }
    return result
  }

  /** 设备类型中文标签。 */
  private kindLabel(deviceType: string): string {
    if (deviceType === 'phone' || deviceType === 'mobile') {
      return '手机'
    }
    if (deviceType === 'desktop' || deviceType === '2in1' || deviceType === 'computer') {
      return '电脑'
    }
    if (deviceType === 'tablet' || deviceType === 'pad') {
      return '平板'
    }
    if (deviceType === 'web') {
      return '网页'
    }
    if (deviceType.length === 0) {
      return '设备'
    }
    return deviceType
  }

  /** 当前选中设备。 */
  private selectedDevice(): DiscoveredDevice | undefined {
    if (this.devices.length === 0) {
      return undefined
    }
    if (this.selectedId.length === 0) {
      return this.devices[0].item
    }
    for (let i = 0; i < this.devices.length; i++) {
      if (this.identityOf(this.devices[i]) === this.selectedId) {
        return this.devices[i].item
      }
    }
    return this.devices[0].item
  }

  private onNodeSelected(id: string): void {
    this.selectedId = id
    this.phase = SceneSendPhase.ready
    this.progress = 0
    this.onTargetChanged(this.selectedDevice())
  }

  /** 发送：有暂存内容才启动视觉进度，真实发送同步交给外部链路。 */
  private fireSend(): void {
    let device: DiscoveredDevice | undefined = this.selectedDevice()
    if (device === undefined) {
      return
    }
    this.onSend(device)
    if (this.viewModel.stagedFiles.length > 0) {
      this.startProgress()
    }
  }

  private startProgress(): void {
    this.stopProgress()
    this.phase = SceneSendPhase.sending
    this.progress = 0
    this.progressTimer = setInterval(() => {
      this.progress += 4
      if (this.progress >= 100) {
        this.progress = 100
        this.stopProgress()
        this.phase = SceneSendPhase.done
      }
    }, SceneMotion.PROGRESS_TICK)
  }

  /** 顶部状态文案区（渐变遮罩下）。 */
  @Builder
  statusHeader() {
    Column() {
      Row({ space: 8 }) {
        ScenePulseDot({ dotSize: 8 })
        Text(this.devices.length > 0 ? '局域网 · 设备发现中' : '局域网 · 等待设备')
          .fontSize(16)
          .fontColor(scenePalette(this.sceneIsDark).onScene)
          .letterSpacing(1)
      }
      Text(this.devices.length > 0 ? `附近 ${this.devices.length} 台设备` : '附近暂无设备')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor(scenePalette(this.sceneIsDark).primary)
        .letterSpacing(0.5)
        .margin({ top: 10 })
      Text('随时可发')
        .fontSize(36)
        .fontWeight(FontWeight.Medium)
        .fontColor(scenePalette(this.sceneIsDark).glow)
        .letterSpacing(2)
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 24, right: 24, top: 18 })
  }

  /** 目标设备卡：玻璃透明材质，叠加在信号场动画底部。 */
  @Builder
  glassInfoCard() {
    Column() {
      GlassCard({ cardRadius: 22, cardPadding: 16 }) {
        Column() {
          // 状态行
          Row() {
            SceneGroupLabel({
              text: '目标设备 · ' + (this.phase === SceneSendPhase.done ? '已送达' :
                this.phase === SceneSendPhase.sending ? '传输中' : '已就绪')
            })
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.lock'))
                .fontSize(12)
                .fontColor([scenePalette(this.sceneIsDark).glow])
              Text('加密传输')
                .fontSize(12)
                .fontColor(scenePalette(this.sceneIsDark).glow)
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          // 目标设备名
          Text(this.selectedDevice() !== undefined ? this.selectedDevice()!.alias : '未选择设备')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(scenePalette(this.sceneIsDark).primary)
            .margin({ top: 6 })

          Text('同一 Wi-Fi · 信号良好 · 无需流量')
            .fontSize(12)
            .fontColor(scenePalette(this.sceneIsDark).muted)
            .margin({ top: 2 })

          // 传输进度（sending / done）
          if (this.phase !== SceneSendPhase.ready) {
            Column() {
              Row() {
                Stack({ alignContent: Alignment.Start }) {
                  Row()
                    .width('100%')
                    .height(4)
                    .borderRadius(999)
                    .backgroundColor(scenePalette(this.sceneIsDark).track)
                  Row()
                    .width(`${this.progress}%`)
                    .height(4)
                    .borderRadius(999)
                    .linearGradient({
                      angle: 90,
                      colors: [
                        [scenePalette(this.sceneIsDark).accent, 0],
                        [scenePalette(this.sceneIsDark).glow, 1]
                      ]
                    })
                    .animation({ duration: 90, curve: Curve.Linear })
                }
                .width('100%')
              }
              Text(this.phase === SceneSendPhase.done ? '文件已安全送达' :
                `正在加密传输 ${this.progress}%`)
                .fontSize(12)
                .fontColor(scenePalette(this.sceneIsDark).glow)
                .margin({ top: 6 })
            }
            .margin({ top: 8 })
            .width('100%')
          }

          // 底部操作行
          Row() {
            Column({ space: 2 }) {
              if (this.viewModel.stagedFileCount() > 0) {
                Text(`已选 ${this.viewModel.stagedFileCount()} 项内容`)
                  .fontSize(12)
                  .fontColor(scenePalette(this.sceneIsDark).muted)
              }
              Text('点按光点切换目标')
                .fontSize(11)
                .fontColor(scenePalette(this.sceneIsDark).mutedSoft)
            }
            .alignItems(HorizontalAlign.Start)

            ScenePillButton({
              label: this.phase === SceneSendPhase.done ? '再发一次' :
                this.phase === SceneSendPhase.sending ? '发送中' : '发送',
              showBrand: true,
              isEnabled: this.phase !== SceneSendPhase.sending,
              onClickAction: () => this.fireSend()
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)
          .margin({ top: 10 })
        }
        .width('100%')
      }
    }
    .width('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: SceneMotion.CARD_ENTER }))
  }

  build() {
    // 信号场动画区：Canvas 铺满整块，玻璃卡叠加在动画底部（对齐 Bottom）
    Stack({ alignContent: Alignment.TopStart }) {
      SignalFieldCanvas({
        nodes: this.buildNodes(),
        onSelectNode: (id: string) => this.onNodeSelected(id)
      })
        .width('100%')
        .height('100%')

      // 顶部渐变遮罩：让文案在场景上清晰
      Column()
        .width('100%')
        .height(220)
        .linearGradient({
          angle: 180,
          colors: [
            [scenePalette(this.sceneIsDark).overlayTop, 0],
            [scenePalette(this.sceneIsDark).overlayMid, 0.55],
            [scenePalette(this.sceneIsDark).overlayEnd, 1]
          ]
        })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        this.statusHeader()
      }
      .width('100%')
      .hitTestBehavior(HitTestMode.None)

      // 目标设备玻璃卡：叠加在动画底部，容器透明让空白处点击落到 Canvas
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          this.glassInfoCard()
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: HERO_EDGE_GAP })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height(SCENE_HEIGHT)
    .borderRadius(20)
    .clip(true)
    .margin({ top: HERO_TOP_GAP, left: HERO_EDGE_GAP, right: HERO_EDGE_GAP })
  }
}
