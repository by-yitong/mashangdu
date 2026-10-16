import 'package:package_info_plus/package_info_plus.dart';

import '../models/models.dart';
import 'api_client.dart';

/// 版本检查：GET /app/latest 的 versionCode 与当前 buildNumber 比较。
class UpdateChecker {
  UpdateChecker(this._api);

  final ApiClient _api;

  /// 检查是否有比当前 buildNumber 更新的版本。
  ///
  /// - 返回 [AppRelease]：有新版本；
  /// - 返回 null：已是最新 / 后端未发布版本（404）；
  /// - 网络或解析异常：原样抛出（调用方决定提示方式）。
  Future<AppRelease?> checkNewer() async {
    final release = await _api.fetchLatestRelease();
    if (release == null) return null;
    final current = await currentBuildNumber();
    if (release.versionCode > current) return release;
    return null;
  }

  /// 静默版：任何失败（含插件缺失、网络异常）都返回 null，绝不抛。
  Future<AppRelease?> checkSilently() async {
    try {
      return await checkNewer();
    } catch (_) {
      return null;
    }
  }

  /// 当前构建号（Android versionCode）；取不到给 0（视为永不提示更新）。
  static Future<int> currentBuildNumber() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }
}
