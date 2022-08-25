import 'package:flutter/material.dart';
import 'package:irmamobile/src/screens/home/widgets/irma_nav_button.dart';
import 'package:irmamobile/src/theme/theme.dart';

enum IrmaNavBarTab {
  home,
  data,
  activity,
  more,
}

class IrmaNavBar extends StatelessWidget {
  final Function(IrmaNavBarTab tab) onChangeTab;
  final IrmaNavBarTab selectedTab;

  const IrmaNavBar({
    Key? key,
    required this.onChangeTab,
    this.selectedTab = IrmaNavBarTab.home,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = IrmaTheme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: theme.tinySpacing),
      // Reduce vertical padding for screens with limited height (i.e. landscape mode).
      height: MediaQuery.of(context).size.height > 450 ? 95 : 85,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade600.withOpacity(0.5),
              blurRadius: 10.0,
              spreadRadius: 1.0,
              offset: const Offset(0, 7))
        ],
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IrmaNavButton(
            key: const Key('nav_button_home'),
            iconData: Icons.home_filled,
            tab: IrmaNavBarTab.home,
            changeTab: onChangeTab,
            isSelected: IrmaNavBarTab.home == selectedTab,
          ),
          IrmaNavButton(
            key: const Key('nav_button_data'),
            iconData: Icons.how_to_reg_outlined,
            tab: IrmaNavBarTab.data,
            changeTab: onChangeTab,
            isSelected: IrmaNavBarTab.data == selectedTab,
          ),
          // Spacing for the QR scan button
          const SizedBox(
            width: 90,
          ),
          IrmaNavButton(
            key: const Key('nav_button_activity'),
            iconData: Icons.history,
            tab: IrmaNavBarTab.activity,
            changeTab: onChangeTab,
            isSelected: IrmaNavBarTab.activity == selectedTab,
          ),
          IrmaNavButton(
            key: const Key('nav_button_more'),
            iconData: Icons.more_horiz,
            tab: IrmaNavBarTab.more,
            changeTab: onChangeTab,
            isSelected: IrmaNavBarTab.more == selectedTab,
          )
        ],
      ),
    );
  }
}
