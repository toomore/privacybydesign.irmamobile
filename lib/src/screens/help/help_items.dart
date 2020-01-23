import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:irmamobile/src/models/irma_configuration.dart';
import 'package:irmamobile/src/theme/theme.dart';
import 'package:irmamobile/src/widgets/collapsible.dart';

class HelpItems extends StatefulWidget {
  const HelpItems({this.credentialType, this.parentKey, this.parentScrollController});

  final CredentialType credentialType;
  final GlobalKey parentKey;
  final ScrollController parentScrollController;

  @override
  _HelpItemsState createState() => _HelpItemsState();
}

class _HelpItemsState extends State<HelpItems> with TickerProviderStateMixin {
  final List<GlobalKey> _collapsableKeys = List<GlobalKey>.generate(5, (int index) => GlobalKey());
  Duration expandDuration = const Duration(milliseconds: 200); // expand duration of _Collapsible

  void _jumpToCollapsable(int index) {
    final RenderObject scrollview = widget.parentKey.currentContext.findRenderObject();
    final RenderBox collapsable = _collapsableKeys[index].currentContext.findRenderObject() as RenderBox;
    widget.parentScrollController.animateTo(
      collapsable.localToGlobal(Offset(0, widget.parentScrollController.offset), ancestor: scrollview).dy,
      duration: const Duration(
        milliseconds: 500,
      ),
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Collapsible(
            header: FlutterI18n.translate(context, 'help.question_1'),
            onExpansionChanged: (v) => {if (v) Future.delayed(expandDuration, () => _jumpToCollapsable(2))},
            content: Container(
              child: MarkdownBody(
                selectable: false,
                data: FlutterI18n.translate(context, 'help.answer_1'),
                styleSheet: MarkdownStyleSheet(
                  strong: IrmaTheme.of(context).textTheme.body2,
                  textScaleFactor: MediaQuery.textScaleFactorOf(
                      context), // TODO remove that addition when "https://github.com/flutter/flutter_markdown/pull/162" is merged
                ),
              ),
            ),
            key: _collapsableKeys[0]),
        Collapsible(
            header: FlutterI18n.translate(context, 'help.question_2'),
            onExpansionChanged: (v) => {if (v) Future.delayed(expandDuration, () => _jumpToCollapsable(3))},
            content: Container(
              child: MarkdownBody(
                selectable: false,
                data: FlutterI18n.translate(context, 'help.answer_2'),
                styleSheet: MarkdownStyleSheet(
                  strong: IrmaTheme.of(context).textTheme.body2,
                  textScaleFactor: MediaQuery.textScaleFactorOf(
                      context), // TODO remove that addition when "https://github.com/flutter/flutter_markdown/pull/162" is merged
                ),
              ),
            ),
            key: _collapsableKeys[1]),
        Collapsible(
            header: FlutterI18n.translate(context, 'help.question_3'),
            onExpansionChanged: (v) => {if (v) Future.delayed(expandDuration, () => _jumpToCollapsable(4))},
            content: Container(
              child: MarkdownBody(
                selectable: false,
                data: FlutterI18n.translate(context, 'help.answer_3'),
                styleSheet: MarkdownStyleSheet(
                  strong: IrmaTheme.of(context).textTheme.body2,
                  textScaleFactor: MediaQuery.textScaleFactorOf(
                      context), // TODO remove that addition when "https://github.com/flutter/flutter_markdown/pull/162" is merged
                ),
              ),
            ),
            key: _collapsableKeys[2]),
        Collapsible(
            header: FlutterI18n.translate(context, 'help.question_4'),
            onExpansionChanged: (v) => {if (v) Future.delayed(expandDuration, () => _jumpToCollapsable(5))},
            content: Container(
              child: MarkdownBody(
                selectable: false,
                data: FlutterI18n.translate(context, 'help.answer_4'),
                styleSheet: MarkdownStyleSheet(
                  strong: IrmaTheme.of(context).textTheme.body2,
                  textScaleFactor: MediaQuery.textScaleFactorOf(
                      context), // TODO remove that addition when "https://github.com/flutter/flutter_markdown/pull/162" is merged
                ),
              ),
            ),
            key: _collapsableKeys[3]),
        Collapsible(
            header: FlutterI18n.translate(context, 'help.question_5'),
            onExpansionChanged: (v) => {if (v) Future.delayed(expandDuration, () => _jumpToCollapsable(6))},
            content: Container(
              child: MarkdownBody(
                selectable: false,
                data: FlutterI18n.translate(context, 'help.answer_5'),
                styleSheet: MarkdownStyleSheet(
                  strong: IrmaTheme.of(context).textTheme.body2,
                  textScaleFactor: MediaQuery.textScaleFactorOf(
                      context), // TODO remove that addition when "https://github.com/flutter/flutter_markdown/pull/162" is merged
                ),
              ),
            ),
            key: _collapsableKeys[4]),
      ],
    );
  }
}
