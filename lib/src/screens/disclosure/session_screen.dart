import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:irmamobile/src/data/irma_repository.dart';
import 'package:irmamobile/src/models/native_events.dart';
import 'package:irmamobile/src/models/session_events.dart';
import 'package:irmamobile/src/models/session_state.dart';
import 'package:irmamobile/src/screens/disclosure/call_info_screen.dart';
import 'package:irmamobile/src/screens/disclosure/session.dart';
import 'package:irmamobile/src/screens/disclosure/widgets/arrow_back_screen.dart';
import 'package:irmamobile/src/screens/disclosure/widgets/disclosure_feedback_screen.dart';
import 'package:irmamobile/src/screens/disclosure/widgets/disclosure_permission.dart';
import 'package:irmamobile/src/screens/disclosure/widgets/issuance_permission.dart';
import 'package:irmamobile/src/screens/disclosure/widgets/session_scaffold.dart';
import 'package:irmamobile/src/screens/error/session_error_screen.dart';
import 'package:irmamobile/src/screens/pin/session_pin_screen.dart';
import 'package:irmamobile/src/util/translated_text.dart';
import 'package:irmamobile/src/widgets/action_feedback.dart';
import 'package:irmamobile/src/widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class SessionScreen extends StatefulWidget {
  static const String routeName = "/session";

  final SessionScreenArguments arguments;

  const SessionScreen({this.arguments}) : super();

  @override
  State<SessionScreen> createState() {
    switch (arguments.sessionType) {
      case "issuing":
      case "disclosing":
      case "signing":
      case "redirect":
        return _SessionScreenState();
      default:
        return _UnknownSessionScreenState();
    }
  }
}

class _UnknownSessionScreenState extends State<SessionScreen> {
  @override
  Widget build(BuildContext context) => ActionFeedback(
        success: false,
        title: TranslatedText(
          "session.unknown_session_type.title",
          style: Theme.of(context).textTheme.headline2,
        ),
        explanation: const TranslatedText(
          "session.unknown_session_type.explanation",
          textAlign: TextAlign.center,
        ),
        onDismiss: () => popToWallet(context),
      );
}

class _SessionScreenState extends State<SessionScreen> {
  final IrmaRepository _repo = IrmaRepository.get();

  SessionStatus _screenStatus = SessionStatus.uninitialized;
  Stream<SessionState> _sessionStateStream;

  bool _isIssuance;
  bool _displayArrowBack = false;

  String get _defaultAppBarTitle => _isIssuance ? "issuance.title" : "disclosure.title";

  @override
  void initState() {
    super.initState();
    _isIssuance = widget.arguments.sessionType == "issuance";
    _sessionStateStream = _repo.getSessionState(widget.arguments.sessionID);
  }

  @override
  void dispose() {
    if ([SessionStatus.requestDisclosurePermission, SessionStatus.requestIssuancePermission].contains(_screenStatus)) {
      _dismissSession();
    }
    super.dispose();
  }

  void _dispatchSessionEvent(SessionEvent event, {bool isBridgedEvent = true}) {
    event.sessionID = widget.arguments.sessionID;
    _repo.dispatch(event, isBridgedEvent: isBridgedEvent);
  }

  void _dismissSession() {
    _dispatchSessionEvent(DismissSessionEvent());
  }

  void _givePermission(SessionState session) {
    if (session.status == SessionStatus.requestDisclosurePermission &&
        (session.issuedCredentials?.isNotEmpty ?? false)) {
      _dispatchSessionEvent(ContinueToIssuanceEvent(), isBridgedEvent: false);
    } else {
      _dispatchSessionEvent(RespondPermissionEvent(
        proceed: true,
        disclosureChoices: session.disclosureChoices,
      ));
    }
  }

  bool _isSpecialIssuanceSession(SessionState session) {
    if (session.issuedCredentials == null) {
      return false;
    }
    if (session.didIssueInappCredential) {
      return true;
    }

    final creds = [
      "pbdf.gemeente.personalData",
      "pbdf.pbdf.email",
      "pbdf.pbdf.mobilenumber",
      "pbdf.pbdf.ideal",
      "pbdf.pbdf.idin",
    ];
    return session.issuedCredentials.where((credential) => creds.contains(credential.info.fullId)).isNotEmpty;
  }

  Widget _buildPinScreen() {
    // SessionPinScreen pops itself from the navigator stack when finished, so here we
    // can simply wait until the screen is finished and show a loading screen as fallback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SessionPinScreen(
          sessionID: widget.arguments.sessionID,
          title: FlutterI18n.translate(context, _defaultAppBarTitle),
        ),
      ));
    });
    return _buildLoadingScreen();
  }

  Widget _buildFinishedContinueSecondDevice(SessionState session) {
    // In case of issuance, always return to the wallet screen.
    if (_isIssuance) {
      WidgetsBinding.instance.addPostFrameCallback((_) => popToWallet(context));
      return _buildLoadingScreen();
    }

    // In case of a disclosure session, return to the wallet after showing a feedback screen.
    final serverName = session.serverName?.name?.translate(FlutterI18n.currentLocale(context).languageCode) ?? "";
    final feedbackType =
        session.status == SessionStatus.success ? DisclosureFeedbackType.success : DisclosureFeedbackType.canceled;
    return DisclosureFeedbackScreen(
      feedbackType: feedbackType,
      otherParty: serverName,
      popToWallet: popToWallet,
    );
  }

  Widget _buildFinishedReturnPhoneNumber(SessionState session) {
    final serverName = session.serverName?.name?.translate(FlutterI18n.currentLocale(context).languageCode) ?? "";

    // Navigate to call info screen when session succeeded.
    // Otherwise cancel the regular way for the particular session type.
    if (session.status == SessionStatus.success) {
      return CallInfoScreen(
        otherParty: serverName,
        clientReturnURL: session.clientReturnURL,
        popToWallet: popToWallet,
      );
    } else if (_isIssuance) {
      WidgetsBinding.instance.addPostFrameCallback((_) => popToWallet(context));
      return _buildLoadingScreen();
    } else {
      return DisclosureFeedbackScreen(
        feedbackType: DisclosureFeedbackType.canceled,
        otherParty: serverName,
        popToWallet: popToWallet,
      );
    }
  }

  Widget _buildFinished(SessionState session) {
    // In case of issuance during disclosure, another session is open in a screen lower in the stack.
    // Ignore clientReturnUrl in this case (issuance) and pop immediately.
    if (_isIssuance && widget.arguments.hasUnderlyingSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).pop());
      return _buildLoadingScreen();
    }

    if (session.continueOnSecondDevice && !session.isReturnPhoneNumber) {
      return _buildFinishedContinueSecondDevice(session);
    }

    if (session.isReturnPhoneNumber) {
      return _buildFinishedReturnPhoneNumber(session);
    }

    // It concerns a mobile session.
    if (session.clientReturnURL != null) {
      // If there is a return URL, navigate to it when we're done
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // canLaunch check is already done in the session repository.
        if (Uri.parse(session.clientReturnURL).queryParameters.containsKey("inapp")) {
          widget.arguments.hasUnderlyingSession && !_isIssuance ? Navigator.of(context).pop() : popToWallet(context);
          if (session.inAppCredential != null && session.inAppCredential != "") {
            _repo.expectInactivationForCredentialType(session.inAppCredential);
          }
          _repo.openURLinAppBrowser(session.clientReturnURL);
        } else {
          _repo.openURLinExternalBrowser(context, session.clientReturnURL);
          widget.arguments.hasUnderlyingSession && !_isIssuance ? Navigator.of(context).pop() : popToWallet(context);
        }
      });
    } else if (_isSpecialIssuanceSession(session)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => popToWallet(context));
    } else {
      // In case of a disclosure having an underlying session we only continue to underlying session
      // if it is a mobile session and there was no clientReturnUrl.
      if (widget.arguments.hasUnderlyingSession) {
        Navigator.of(context).pop();
        return _buildLoadingScreen();
      }

      // Otherwise, on iOS show a screen to press the return arrow in the top-left corner,
      // and on Android just background the app to let the user return to the previous activity
      if (Platform.isIOS) {
        return ArrowBack();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          IrmaRepository.get().bridgedDispatch(AndroidSendToBackgroundEvent());
          popToWallet(context);
        });
      }
    }
    return _buildLoadingScreen();
  }

  Widget _buildErrorScreen(SessionState session) {
    if (_displayArrowBack) {
      return ArrowBack();
    }
    return SessionErrorScreen(
        error: session.error,
        onTapClose: () {
          if (session.continueOnSecondDevice) {
            popToWallet(context);
          } else if (session.clientReturnURL != null && !session.isReturnPhoneNumber) {
            // canLaunch check is already done in the session repository.
            launch(session.clientReturnURL, forceSafariVC: false);
            popToWallet(context);
          } else {
            if (Platform.isIOS) {
              setState(() => _displayArrowBack = true);
            } else {
              IrmaRepository.get().bridgedDispatch(AndroidSendToBackgroundEvent());
              popToWallet(context);
            }
          }
        });
  }

  Widget _buildLoadingScreen() => SessionScaffold(
        body: Column(children: [
          Center(
            child: LoadingIndicator(),
          ),
        ]),
        onDismiss: () => _dismissSession(),
        appBarTitle: _defaultAppBarTitle,
      );

  @override
  Widget build(BuildContext context) => StreamBuilder(
      stream: _sessionStateStream,
      builder: (BuildContext context, AsyncSnapshot<SessionState> sessionStateSnapshot) {
        if (!sessionStateSnapshot.hasData) {
          return _buildLoadingScreen();
        }

        final session = sessionStateSnapshot.data;
        if (_screenStatus != session.status) {
          _screenStatus = session.status;
        }

        switch (session.status) {
          case SessionStatus.requestDisclosurePermission:
            return DisclosurePermission(
              session: session,
              onDismiss: () => _dismissSession(),
              onGivePermission: () => _givePermission(session),
              dispatchSessionEvent: _dispatchSessionEvent,
            );
          case SessionStatus.requestIssuancePermission:
            // In case of session type "redirect" we might have guessed the session type wrongly.
            _isIssuance = true;
            return IssuancePermission(
              satisfiable: session.satisfiable,
              issuedCredentials: session.issuedCredentials,
              onDismiss: () => _dismissSession(),
              onGivePermission: () => _givePermission(session),
            );
          case SessionStatus.requestPin:
            return _buildPinScreen();
          case SessionStatus.error:
            return _buildErrorScreen(session);
          case SessionStatus.success:
          case SessionStatus.canceled:
            return _buildFinished(session);
          default:
            return _buildLoadingScreen();
        }
      });
}
