import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:irmamobile/src/data/irma_preferences.dart';
import 'package:irmamobile/src/data/irma_repository.dart';
import 'package:irmamobile/src/models/attributes.dart';
import 'package:irmamobile/src/models/session_events.dart';
import 'package:irmamobile/src/models/session_state.dart';
import 'package:irmamobile/src/screens/disclosure/widgets/arrow_back_screen.dart';
import 'package:irmamobile/src/screens/wallet/wallet_screen.dart';
import 'package:irmamobile/src/theme/theme.dart';
import 'package:irmamobile/src/widgets/irma_app_bar.dart';
import 'package:irmamobile/src/widgets/irma_bottom_bar.dart';
import 'package:irmamobile/src/widgets/irma_button.dart';
import 'package:irmamobile/src/widgets/irma_dialog.dart';
import 'package:irmamobile/src/widgets/irma_quote.dart';
import 'package:irmamobile/src/widgets/irma_text_button.dart';
import 'package:irmamobile/src/widgets/irma_themed_button.dart';
import 'package:irmamobile/src/widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'carousel.dart';

class DisclosureScreenArguments {
  final int sessionID;

  DisclosureScreenArguments({this.sessionID});
}

class DisclosureScreen extends StatefulWidget {
  static const String routeName = "/disclosure";

  final DisclosureScreenArguments arguments;

  const DisclosureScreen({this.arguments}) : super();

  @override
  _DisclosureScreenState createState() => _DisclosureScreenState();
}

class _DisclosureScreenState extends State<DisclosureScreen> {
  final String _lang = "nl";
  final IrmaRepository _repo = IrmaRepository.get();
  Stream<SessionState> _sessionStateStream;

  bool _displayArrowBack = false;

  @override
  void initState() {
    super.initState();

    _sessionStateStream = _repo.getSessionState(widget.arguments.sessionID);

    _sessionStateStream
        .firstWhere((session) => session.disclosuresCandidates != null)
        .then((session) => _showExplanation(session.disclosuresCandidates));

    // Session success handling
    (() async {
      // When the session has completed, wait one second to display a message
      final session = await _sessionStateStream.firstWhere((session) => session.status == SessionStatus.success);
      await Future.delayed(const Duration(seconds: 1));

      if (session.continueOnSecondDevice) {
        // If this is a session on another screen, just pop to the wallet
        _popToWallet(context);
      } else if (session.clientReturnURL != null && await canLaunch(session.clientReturnURL)) {
        // If there is a return URL, navigate to it when we're done
        launch(session.clientReturnURL, forceSafariVC: false);
        _popToWallet(context);
      } else {
        // Otherwise, on iOS show a screen to press the return arrow in the top-left corner,
        // and on Android just background the app to let the user return to the previous activity
        if (Platform.isIOS) {
          setState(() => _displayArrowBack = true);
        } else {
          SystemNavigator.pop();
          _popToWallet(context);
        }
      }
    })();
  }

  void _popToWallet(BuildContext context) {
    Navigator.of(context).popUntil(ModalRoute.withName(WalletScreen.routeName));
  }

  void _dispatchSessionEvent(SessionEvent event) {
    event.sessionID = widget.arguments.sessionID;
    _repo.bridgedDispatch(event);
  }

  void _dismissSession() {
    _dispatchSessionEvent(DismissSessionEvent());
  }

  void _declinePermission(BuildContext context) {
    _dispatchSessionEvent(RespondPermissionEvent(
      proceed: false,
      disclosureChoices: [],
    ));

    Navigator.of(context).pop();
  }

  void _givePermission(SessionState session) {
    _dispatchSessionEvent(RespondPermissionEvent(
      proceed: true,
      disclosureChoices: session.disclosuresCandidates.map((discon) {
        return discon.first
            .map((credentialAttribute) => AttributeIdentifier.fromCredentialAttribute(credentialAttribute))
            .toList();
      }).toList(),
    ));
  }

  Widget _buildDisclosureHeader(SessionState session) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: FlutterI18n.translate(context, 'disclosure.disclosure_header.start'),
            style: IrmaTheme.of(context).textTheme.body1),
        TextSpan(
          text: session.serverName.translate(_lang),
          style: IrmaTheme.of(context).textTheme.body2,
        ),
        TextSpan(
          text: FlutterI18n.translate(context, 'disclosure.disclosure_header.end'),
          style: IrmaTheme.of(context).textTheme.body1,
        ),
      ]),
    );
  }

  Widget _buildSigningHeader(SessionState session) {
    return Column(children: [
      Text.rich(
        TextSpan(children: [
          TextSpan(
            text: session.serverName.translate(_lang),
            style: IrmaTheme.of(context).textTheme.body2,
          ),
          TextSpan(
            text: FlutterI18n.translate(context, 'disclosure.signing_header'),
            style: IrmaTheme.of(context).textTheme.body1,
          ),
        ]),
      ),
      Padding(
        padding: EdgeInsets.only(top: IrmaTheme.of(context).mediumSpacing),
        child: IrmaQuote(quote: session.signedMessage),
      ),
    ]);
  }

  Widget _buildNavigationBar() {
    return StreamBuilder<SessionState>(
      stream: _sessionStateStream,
      builder: (context, sessionStateSnapshot) {
        if (!sessionStateSnapshot.hasData || sessionStateSnapshot.data.status != SessionStatus.requestPermission) {
          return Container(height: 0);
        }

        return IrmaBottomBar(
          primaryButtonLabel: FlutterI18n.translate(context, "disclosure.navigation_bar.yes"),
          onPrimaryPressed: () => _givePermission(sessionStateSnapshot.data),
          secondaryButtonLabel: FlutterI18n.translate(context, "disclosure.navigation_bar.no"),
          onSecondaryPressed: () => _declinePermission(context),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(children: [
      Center(
        child: LoadingIndicator(),
      ),
    ]);
  }

  Widget _buildDisclosureChoices(SessionState session) {
    // TODO: See how disclosure_card.dart fits in here
    return ListView(
      padding: EdgeInsets.all(IrmaTheme.of(context).smallSpacing),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: IrmaTheme.of(context).mediumSpacing,
            horizontal: IrmaTheme.of(context).smallSpacing,
          ),
          child: session.isSignatureSession ? _buildSigningHeader(session) : _buildDisclosureHeader(session),
        ),
        Card(
          elevation: 1.0,
          semanticContainer: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(IrmaTheme.of(context).defaultSpacing),
            side: const BorderSide(color: Color(0xFFDFE3E9), width: 1),
          ),
          color: IrmaTheme.of(context).primaryLight,
          child: Column(
            children: [
              SizedBox(height: IrmaTheme.of(context).smallSpacing),
              ...session.disclosuresCandidates
                  .asMap()
                  .entries
                  .expand(
                    (entry) => [
                      // Display a divider except for the first element
                      if (entry.key != 0)
                        Divider(
                          color: IrmaTheme.of(context).grayscale80,
                        ),
                      Carousel(candidatesDisCon: entry.value)
                    ],
                  )
                  .toList(),
              SizedBox(height: IrmaTheme.of(context).smallSpacing),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_displayArrowBack) {
      return ArrowBack();
    }

    return Scaffold(
      appBar: IrmaAppBar(
        title: Text(FlutterI18n.translate(context, 'disclosure.title')),
      ),
      backgroundColor: IrmaTheme.of(context).grayscaleWhite,
      bottomNavigationBar: _buildNavigationBar(),
      body: StreamBuilder(
        stream: _sessionStateStream,
        builder: (BuildContext context, AsyncSnapshot<SessionState> sessionStateSnapshot) {
          if (!sessionStateSnapshot.hasData) {
            return _buildLoadingIndicator();
          }

          final session = sessionStateSnapshot.data;
          if (session.status == SessionStatus.requestPermission) {
            return _buildDisclosureChoices(session);
          }

          if (session.status == SessionStatus.success) {
            return Center(
              child: Text(
                FlutterI18n.translate(context, "disclosure.redirect"),
              ),
            );
          }

          return _buildLoadingIndicator();
        },
      ),
    );
  }

  Future<void> _showExplanation(ConDisCon<CredentialAttribute> candidatesConDisCon) async {
    final irmaPrefs = IrmaPreferences.get();

    final bool showDisclosureDialog = await irmaPrefs.getShowDisclosureDialog().first;
    final hasChoice = candidatesConDisCon.any((candidatesDisCon) => candidatesDisCon.length > 1);

    if (!showDisclosureDialog || !hasChoice) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) => IrmaDialog(
        title: 'disclosure.explanation.title',
        content: 'disclosure.explanation.body',
        image: 'assets/disclosure/disclosure-explanation.webp',
        child: Wrap(
          direction: Axis.horizontal,
          verticalDirection: VerticalDirection.up,
          alignment: WrapAlignment.spaceEvenly,
          children: <Widget>[
            IrmaTextButton(
              onPressed: () async {
                await irmaPrefs.setShowDisclosureDialog(false);
                Navigator.of(context).pop();
              },
              minWidth: 0.0,
              label: 'disclosure.explanation.dismiss-remember',
            ),
            IrmaButton(
              size: IrmaButtonSize.small,
              minWidth: 0.0,
              onPressed: () {
                Navigator.of(context).pop();
              },
              label: 'disclosure.explanation.dismiss',
            ),
          ],
        ),
      ),
    );
  }
}
