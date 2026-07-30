part of 'auth_cubit.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

/// Login succeeded and the user's email is verified — proceed to dashboard.
class AuthSuccess extends AuthState {}

/// Login succeeded but the user's email is not yet verified — route to
/// the verification screen instead of the dashboard.
class AuthUnverified extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
