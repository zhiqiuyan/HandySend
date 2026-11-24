/**
 * SceneTokens.ets — 方向 B「信号场 / Signal Field」视觉令牌
 *
 * 来源：design-demos/dir-2.html（方向 B · 场景诗意 · 借 Raylie 的机制）。
 * 提供「深蓝沉浸（夜）」与「浅蓝留白（昼）」两套色板，随系统深浅色自动切换。
 *
 * 重要：ArkUI 的带透明度色值格式是 #AARRGGBB（高位是 alpha），
 * 不是 CSS 的 #RRGGBBAA。所有 8 位色值一律按 #AARRGGBB 书写，
 * 避免 #FFFFFF21 被解析成不透明的黄色 #FFFF21。
 */

/** 一套完整场景色板。所有值均为 #AARRGGBB（8 位）或 #RRGGBB（6 位）。 */
export interface ScenePalette {
  // 场景底与渐变
  base: string
  deep: string
  deep2: string
  deep3: string
  softTop: string
  softMid: string
  // 品牌与辉光
  accent: string
  accentText: string
  glow: string
  glowStrong: string
  arcPoint: string
  success: string
  // 文本
  white: string
  primary: string
  muted: string
  mutedSoft: string
  onScene: string
  // 玻璃材质
  glassTop: string
  glassBottom: string
  glassBorder: string
  hairline: string
  track: string
  // 涟漪 / 光晕
  ripple: string
  haloIn: string
  haloMid: string
  // 顶部文案遮罩
  overlayTop: string
  overlayMid: string
  overlayEnd: string
}

/** 夜间色板：方向 B 深蓝沉浸场景。 */
const DARK_PALETTE: ScenePalette = {
  base: '#050912',
  deep: '#070D1B',
  deep2: '#101C33',
  deep3: '#1B3358',
  softTop: '#16294A',
  softMid: '#0B1426',
  accent: '#2779C6',
  accentText: '#5599FF',
  glow: '#8CC8FF',
  glowStrong: '#C4E4FF',
  arcPoint: '#D8EEFF',
  success: '#8CE0B0',
  white: '#FFFFFFFF',
  primary: '#EAF2FF',
  muted: '#ADBAD1EF',
  mutedSoft: '#B896B9E1',
  onScene: '#D1BED7F5',
  glassTop: '#21FFFFFF',
  glassBottom: '#0BFFFFFF',
  glassBorder: '#29FFFFFF',
  hairline: '#1FFFFFFF',
  track: '#1FFFFFFF',
  ripple: '#7FC0FF',
  haloIn: '#5AA6FF',
  haloMid: '#2779C6',
  overlayTop: '#DB040914',
  overlayMid: '#47040914',
  overlayEnd: '#00040914'
}

/** 日间色板：浅蓝留白场景（与全局浅色主题一致）。 */
const LIGHT_PALETTE: ScenePalette = {
  base: '#F2F3F5',
  deep: '#E8F0FA',
  deep2: '#D6E6F8',
  deep3: '#B9D8F6',
  softTop: '#FFFFFFFF',
  softMid: '#F5F9FE',
  accent: '#006CDE',
  accentText: '#006CDE',
  glow: '#2E7BC9',
  glowStrong: '#1A5FA8',
  arcPoint: '#006CDE',
  success: '#277F27',
  white: '#FFFFFFFF',
  primary: '#182431',
  muted: '#6B5A6B7C',
  mutedSoft: '#78667889',
  onScene: '#33445C',
  glassTop: '#4DFFFFFF',
  glassBottom: '#2BFFFFFF',
  glassBorder: '#33006CDE',
  hairline: '#2E182431',
  track: '#2E182431',
  ripple: '#2E7BC9',
  haloIn: '#4A90D9',
  haloMid: '#1F006CDE',
  overlayTop: '#E6F2F3F5',
  overlayMid: '#4DF2F3F5',
  overlayEnd: '#00F2F3F5'
}

/** 场景色板的全局响应式开关：true=深色（夜），false=浅色（昼）。 */
const SCENE_DARK_KEY: string = 'sceneIsDark'

/** 读取当前场景色板。组件用 watchSceneTheme 轮询 isSceneDark() 触发重绘。 */
export function scenePalette(isDark: boolean): ScenePalette {
  return isDark ? DARK_PALETTE : LIGHT_PALETTE
}

/** 读取当前是否深色场景（供 Canvas 定时重绘使用）。 */
export function isSceneDark(): boolean {
  return AppStorage.get<boolean>(SCENE_DARK_KEY) ?? false
}

/** 初始化场景色模式（EntryAbility 启动时与配置变化时调用）。 */
export function setSceneDark(isDark: boolean): void {
  AppStorage.setOrCreate<boolean>(SCENE_DARK_KEY, isDark)
}

/**
 * V2 组件不支持 @StorageProp，用轻量轮询同步主题（系统切换时机不频繁，400ms 足够跟手）。
 * 返回定时器 id，组件 aboutToDisappear 时用 stopSceneThemeWatch 释放。
 */
export function watchSceneTheme(onChange: (isDark: boolean) => void): number {
  let last: boolean = isSceneDark()
  return setInterval(() => {
    let current: boolean = isSceneDark()
    if (current !== last) {
      last = current
      onChange(current)
    }
  }, 400)
}

/** 停止主题轮询。 */
export function stopSceneThemeWatch(timerId: number): void {
  if (timerId >= 0) {
    clearInterval(timerId)
  }
}

/** 方向 B 动效参数（毫秒）。 */
export class SceneMotion {
  static readonly RIPPLE_DURATION: number = 4200;   // 涟漪扩散 4.2s
  static readonly RIPPLE_STAGGER: number = 1400;    // 三条涟漪错峰 1.4s
  static readonly FLOW_DURATION: number = 3000;     // 光点沿弧线流动 3.0~3.6s
  static readonly ARC_DASH: number = 2400;          // 弧线虚线流动 2.4s
  static readonly PULSE_DURATION: number = 1800;    // 呼吸点 1.8s
  static readonly CARD_ENTER: number = 420;         // 玻璃卡入场
  static readonly PROGRESS_TICK: number = 90;       // 传输进度刷新间隔
}

/** 场景设备节点（信号场绘制用的归一化坐标，取值 0~1）。 */
export interface SceneNode {
  id: string
  name: string
  kind: string
  x: number
  y: number
  selected: boolean
}
