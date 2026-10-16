/// 相对时间：x分钟前 / x小时前 / x天前。
///
/// - < 1 分钟：刚刚
/// - < 1 小时：N 分钟前
/// - < 24 小时：N 小时前
/// - < 30 天：N 天前
/// - 更早 / 解析失败 / 未来时间超出 1 分钟：yyyy-MM-dd（失败给 '—'）
String relativeTime(DateTime? time, {DateTime? now}) {
  if (time == null) return '—';
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.isNegative) {
    // 服务器/本机时钟轻微偏差（< 1 分钟）按“刚刚”处理。
    return diff.inMinutes > -1 ? '刚刚' : '—';
  }
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  final y = time.year.toString().padLeft(4, '0');
  final m = time.month.toString().padLeft(2, '0');
  final d = time.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 阅读页状态条本地时间：24 小时制 HH:mm（如 20:05、09:07）。
String formatHm(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
