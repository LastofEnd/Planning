import 'package:local_auth/local_auth.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';

class LockService {
  LockService._();
  static final LockService instance = LockService._();

  final _auth = LocalAuthentication();

  Future<bool> promptIfNeeded({required bool requiredLock}) async {
    if (!requiredLock) return true;
    return await authenticate();
  }

  Future<bool> authenticate() async {
    try {
      final canCheck =
          (await _auth.canCheckBiometrics) || (await _auth.isDeviceSupported());
      if (!canCheck) return false;

      final ok = await _auth.authenticate(
        localizedReason: AppController.instance.t('auth.reason'),
        options: const AuthenticationOptions(
          biometricOnly: false,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      return ok;
    } catch (_) {
      return false;
    }
  }
}
