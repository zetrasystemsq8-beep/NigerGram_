// Add this near the top of wallet_home_view.dart, outside the class:

const String kAdminUid = String.fromEnvironment('ADMIN_UID', defaultValue: '');

// Then inside _WalletHomeViewState, add to the AppBar's actions list
// (alongside the existing refresh IconButton), so it only renders for
// your account:

actions: [
  if (kAdminUid.isNotEmpty && Supabase.instance.client.auth.currentUser?.id == kAdminUid)
    IconButton(
      icon: const Icon(Icons.admin_panel_settings_rounded),
      color: Colors.white,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminGateView()),
        );
      },
    ),
  IconButton(
    icon: _isRefreshing
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: Color(0xFFFF0050), strokeWidth: 2),
          )
        : const Icon(Icons.refresh_rounded),
    onPressed: _isRefreshing ? null : _refresh,
    color: Colors.white,
  ),
],

// Don't forget the import at the top of the file:
// import 'package:nigergram/features/admin/presentation/view/admin_gate_view.dart';
