/// 阅读页目录面板松手后的开合吸附判定（纯函数，可单测）。
///
/// 双判定：速度优先、位置兜底——
/// - 向右速度 ≥ [flingVelocity]（px/s，向右开面板）→ 开；
/// - 向左速度 ≤ -[flingVelocity] → 关；
/// - 速度不足（慢拖）按位置阈值 [positionThreshold]（0.5，拖过半开）。
bool drawerSnapOpen(
  double position,
  double velocityDx, {
  double flingVelocity = 600,
  double positionThreshold = 0.5,
}) {
  if (velocityDx >= flingVelocity) return true;
  if (velocityDx <= -flingVelocity) return false;
  return position >= positionThreshold;
}
