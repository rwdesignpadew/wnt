import 'package:flutter/material.dart';

import '../../core/theme/wnt_colors.dart';

class WntFilterTab<T> {
  const WntFilterTab({required this.value, required this.label});

  final T value;
  final String label;
}

class WntFilterTabs<T> extends StatelessWidget {
  const WntFilterTabs({
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<WntFilterTab<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          _Tab<T>(
            item: items[index],
            selected: items[index].value == value,
            onTap: onChanged,
          ),
        ],
      ],
    ),
  );
}

class _Tab<T> extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final WntFilterTab<T> item;
  final bool selected;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? WntColors.brand : const Color(0xFFF2F4F7),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onTap(item.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Text(
          item.label,
          style: TextStyle(
            color: selected ? Colors.white : WntColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    ),
  );
}
