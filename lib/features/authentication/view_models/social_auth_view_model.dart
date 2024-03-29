import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:surfify/features/main_navigation/main_navigation_screen.dart';
import '../../../utils.dart';
import '../../users/view_models/user_view_model.dart';
import '../repos/authentication_repo.dart';
import '../views/policy_agreement_screen.dart';

class SocialAuthViewModel extends AsyncNotifier<void> {
  late final AuthenticaitonRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.read(authRepo);
  }

  Future<void> googleSignUp(BuildContext context) async {
    late final uid = ref.read(authRepo).user!.uid;

    late final users = ref.read(usersProvider(uid).notifier);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final userCredential = await _repository.googleSignIn();
      if (ref.read(usersProvider(uid)).value == null) {
        await users.createAccount(userCredential);
      }
    });
    if (state.hasError) {
      showFirebaseErrorSnack(context, state.error);
    } else if (ref.read(usersProvider(uid)).value!.serviceAgree == true) {
      context.go(MainNavigationScreen.routeName);
    } else {
      context.go(PolicyAgreementScreen.routeName);
    }
  }

  Future<void> googleSignIn(BuildContext context) async {
    late final uid = ref.read(authRepo).user!.uid;
    late final users = ref.read(usersProvider(uid).notifier);

    late final UserCredential userCredential;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      userCredential = await _repository.googleSignIn();
    });
    if (state.hasError) {
      showFirebaseErrorSnack(context, state.error);
    } else if (ref.read(usersProvider(uid)).value != null) {
      context.go(MainNavigationScreen.routeName);
    } else {
      await users.createAccount(userCredential);
      context.go(PolicyAgreementScreen.routeName);
    }
  }
}

final socialAuthProvider = AsyncNotifierProvider<SocialAuthViewModel, void>(
  () => SocialAuthViewModel(),
);
