import 'package:flutter/material.dart';

class WntSearchableSelectField extends StatelessWidget {
  const WntSearchableSelectField({
    required this.label,
    required this.onTap,
    this.value,
    this.hintText = 'Wybierz',
    super.key,
  });

  final String label;
  final String? value;
  final String hintText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selectedValue = value?.trim();
    final hasValue = selectedValue?.isNotEmpty == true;

    return Semantics(
      button: true,
      label: label,
      value: hasValue ? selectedValue : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: InputDecorator(
          isEmpty: !hasValue,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.search),
          ),
          child: Text(
            hasValue ? selectedValue! : hintText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hasValue
                ? null
                : Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
          ),
        ),
      ),
    );
  }
}

Future<T?> showWntSearchPicker<T>({
  required BuildContext context,
  required String title,
  required String searchHint,
  required List<T> items,
  required String Function(T item) titleFor,
  required String Function(T item) searchTextFor,
  String? Function(T item)? subtitleFor,
  T? selected,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _WntSearchPickerSheet<T>(
    title: title,
    searchHint: searchHint,
    items: items,
    titleFor: titleFor,
    searchTextFor: searchTextFor,
    subtitleFor: subtitleFor,
    selected: selected,
  ),
);

class _WntSearchPickerSheet<T> extends StatefulWidget {
  const _WntSearchPickerSheet({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.titleFor,
    required this.searchTextFor,
    required this.subtitleFor,
    required this.selected,
  });

  final String title;
  final String searchHint;
  final List<T> items;
  final String Function(T item) titleFor;
  final String Function(T item) searchTextFor;
  final String? Function(T item)? subtitleFor;
  final T? selected;

  @override
  State<_WntSearchPickerSheet<T>> createState() =>
      _WntSearchPickerSheetState<T>();
}

class _WntSearchPickerSheetState<T> extends State<_WntSearchPickerSheet<T>> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final visibleItems = normalizedQuery.isEmpty
        ? widget.items
        : widget.items
              .where(
                (item) => widget
                    .searchTextFor(item)
                    .toLowerCase()
                    .contains(normalizedQuery),
              )
              .toList();

    return FractionallySizedBox(
      heightFactor: .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Zamknij',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visibleItems.isEmpty
                ? const Center(child: Text('Brak pasujących klientów.'))
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final subtitle = widget.subtitleFor?.call(item)?.trim();
                      final isSelected =
                          identical(item, widget.selected) ||
                          item == widget.selected;
                      return ListTile(
                        selected: isSelected,
                        leading: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.person_outline,
                        ),
                        title: Text(
                          widget.titleFor(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: subtitle?.isNotEmpty == true
                            ? Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
