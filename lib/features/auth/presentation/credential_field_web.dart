import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'credential_field.dart';

/// The `<form>` both inputs belong to, through their `form` attribute.
///
/// A password manager recognises a login form by a username and a password
/// field in the same form. The inputs live inside Flutter's platform views,
/// which cannot share one parent element, so the form sits empty at the end of
/// the page and the inputs name it instead.
const String _formId = 'heimdall-sign-in';

/// The class every credential input carries, which the injected style sheet
/// targets.
const String _inputClass = 'heimdall-credential';

web.HTMLFormElement _signInForm() {
  final existing = web.document.getElementById(_formId);

  if (existing != null) {
    return existing as web.HTMLFormElement;
  }

  final form = web.document.createElement('form') as web.HTMLFormElement
    ..id = _formId
    ..method = 'post'
    ..action = '#'
    ..autocomplete = 'on'
    // The app validates, in its own words; the browser's bubbles would only
    // duplicate them.
    ..noValidate = true;

  // A submission tells password managers the credentials were used. The app
  // signs in itself, so the page never actually navigates.
  form.addEventListener(
    'submit',
    ((web.Event event) => event.preventDefault()).toJS,
  );

  // A browser paints autofilled inputs with its own background and text
  // colour, which a pseudo-class alone can reach; the field's colours are
  // passed in as custom properties.
  final style = web.document.createElement('style')
    ..textContent =
        'input.$_inputClass:-webkit-autofill,'
        'input.$_inputClass:-webkit-autofill:hover,'
        'input.$_inputClass:-webkit-autofill:focus{'
        '-webkit-text-fill-color:var(--heimdall-text);'
        'caret-color:var(--heimdall-caret);'
        'transition:background-color 600000s 0s,color 600000s 0s;}';

  web.document.head?.append(style);
  web.document.body?.append(form);

  return form;
}

String _css(Color color) =>
    'rgba(${(color.r * 255).round()}, ${(color.g * 255).round()}, '
    '${(color.b * 255).round()}, ${color.a})';

/// A credential as a real HTML input, laid out inside a Material field.
///
/// The input is always in the page, at its full size, and in the sign-in
/// form, which is what a password manager extension needs in order to offer
/// and fill it. Flutter still draws the label, the outline, and the
/// validation message around it, so it looks like every other field.
class CredentialField extends StatefulWidget {
  const CredentialField({
    required this.kind,
    required this.controller,
    required this.label,
    required this.validator,
    this.onSubmitted,
    this.enabled = true,
    super.key,
  });

  final CredentialKind kind;
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;

  /// Called when Enter is pressed in the field.
  final VoidCallback? onSubmitted;
  final bool enabled;

  @override
  State<CredentialField> createState() => _CredentialFieldState();
}

class _CredentialFieldState extends State<CredentialField> {
  web.HTMLInputElement? _input;
  bool _focused = false;

  /// Holds Flutter's focus while the input has the page's.
  ///
  /// Flutter's own shortcuts would otherwise take the keys typed into the
  /// input — Tab for its focus traversal, the arrows, Space — cancelling them
  /// before the browser could move on to the next field, move the caret, or
  /// type a space. Skipping the remaining handlers reports every key as not
  /// Flutter's, so the browser does with it what it does with any input.
  late final FocusNode _keys = FocusNode(
    debugLabel: 'Credential: ${widget.label}',
    skipTraversal: true,
    onKeyEvent: (node, event) => KeyEventResult.skipRemainingHandlers,
  );

  bool get _isPassword => widget.kind == CredentialKind.password;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_pushToInput);
  }

  @override
  void didUpdateWidget(CredentialField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_pushToInput);
      widget.controller.addListener(_pushToInput);
      _pushToInput();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_pushToInput);
    _keys.dispose();
    super.dispose();
  }

  /// Copies the controller into the input when the app changed it — the
  /// password cleared after a refusal, say.
  void _pushToInput() {
    final input = _input;

    if (input != null && input.value != widget.controller.text) {
      input.value = widget.controller.text;
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Copies what was typed or filled in into the controller. Password
  /// managers announce a fill with `input`, `change`, or both.
  void _pullFromInput() {
    final value = _input?.value ?? '';

    if (value != widget.controller.text) {
      widget.controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  void _bind(Object element) {
    final input = element as web.HTMLInputElement
      ..type = _isPassword ? 'password' : 'email'
      ..name = _isPassword ? 'password' : 'username'
      ..id = _isPassword ? 'heimdall-password' : 'heimdall-username'
      ..autocomplete = _isPassword ? 'current-password' : 'username'
      ..className = _inputClass
      ..spellcheck = false
      ..value = widget.controller.text
      ..disabled = !widget.enabled;

    input
      ..setAttribute('form', _signInForm().id)
      ..setAttribute('aria-label', widget.label)
      ..setAttribute('autocapitalize', 'off')
      ..setAttribute('autocorrect', 'off');

    input.addEventListener('input', ((web.Event _) => _pullFromInput()).toJS);
    input.addEventListener('change', ((web.Event _) => _pullFromInput()).toJS);
    input.addEventListener(
      'focus',
      ((web.Event _) {
        _keys.requestFocus();
        setState(() => _focused = true);
      }).toJS,
    );
    input.addEventListener(
      'blur',
      ((web.Event _) {
        if (_keys.hasFocus) {
          _keys.unfocus();
        }

        setState(() => _focused = false);
      }).toJS,
    );
    input.addEventListener(
      'keydown',
      ((web.KeyboardEvent event) {
        if (event.key != 'Enter') {
          return;
        }

        event.preventDefault();

        if (_isPassword) {
          widget.onSubmitted?.call();
        } else {
          // From the address, Enter moves on to the password, as Tab does.
          (web.document.getElementById('heimdall-password') as web.HTMLElement?)
              ?.focus();
        }
      }).toJS,
    );

    _input = input;
    _style();
  }

  /// Matches the input to the theme. Run on every build, so a switch between
  /// light and dark reaches it too.
  void _style() {
    final input = _input;

    if (input == null) {
      return;
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = widget.enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final fontSize = theme.textTheme.bodyLarge?.fontSize ?? 16;

    input.disabled = !widget.enabled;
    input.style
      ..setProperty('--heimdall-text', _css(text))
      ..setProperty('--heimdall-caret', _css(scheme.primary))
      ..width = '100%'
      ..height = '100%'
      ..margin = '0'
      ..padding = '0'
      ..border = 'none'
      ..outline = 'none'
      ..background = 'transparent'
      ..color = _css(text)
      ..caretColor = _css(scheme.primary)
      ..fontFamily = 'Roboto, system-ui, -apple-system, "Segoe UI", sans-serif'
      ..fontSize = '${fontSize}px'
      ..lineHeight = '24px'
      ..boxSizing = 'border-box';
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _style();
      }
    });

    return FormField<String>(
      validator: (_) => widget.validator(widget.controller.text),
      builder: (field) => Focus(
        focusNode: _keys,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            errorText: field.errorText,
            enabled: widget.enabled,
          ),
          isFocused: _focused,
          isEmpty: widget.controller.text.isEmpty,
          child: SizedBox(
            height: 24,
            child: HtmlElementView.fromTagName(
              tagName: 'input',
              onElementCreated: _bind,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells the page's password manager the credentials were submitted, so it
/// can offer to save them.
void announceCredentialsSubmitted() => _signInForm().requestSubmit();
