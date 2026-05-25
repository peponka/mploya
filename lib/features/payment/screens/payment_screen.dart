import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/core/services/stripe_service.dart';
import 'package:mploya/core/services/supabase_service.dart';

/// Datos del producto a pagar.
class PaymentProduct {
  final String name;
  final String description;
  final double price;
  final String? duration;
  final IconData icon;
  final Color color;

  const PaymentProduct({
    required this.name,
    required this.description,
    required this.price,
    this.duration,
    this.icon = Icons.shopping_bag_outlined,
    this.color = const Color(0xFFF97316),
  });
}

/// Pantalla de pasarela de pago reutilizable.
///
/// Se usa para cualquier compra en la app: Boost, Premium, etc.
/// Recibe un [PaymentProduct] via GoRouter `extra`.
class PaymentScreen extends StatefulWidget {
  final PaymentProduct? product;

  const PaymentScreen({super.key, this.product});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  int _selectedMethod = 0;
  bool _isProcessing = false;

  static const _paymentMethods = [
    ('💳', 'Tarjeta de crédito'),
    ('🏦', 'Tarjeta de débito'),
    ('', 'Apple Pay'),
    ('', 'Google Pay'),
  ];

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  PaymentProduct get _product =>
      widget.product ??
      const PaymentProduct(
        name: 'Producto',
        description: 'Descripción del producto',
        price: 0.0,
      );

  Future<void> _handlePay() async {
    // Si Stripe no está configurado, mostrar mensaje informativo.
    if (!StripeService.instance.isConfigured) {
      _showNotConfiguredMessage();
      return;
    }

    // Procesar pago real con Stripe Payment Sheet.
    await _handleStripePayment();
  }

  /// Procesa el pago usando Stripe Payment Sheet.
  Future<void> _handleStripePayment() async {
    setState(() => _isProcessing = true);

    try {
      // Obtener userId del usuario autenticado.
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Debés iniciar sesión para realizar un pago.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
        return;
      }

      // Convertir precio a centavos para Stripe.
      final amountInCents = (_product.price * 100).round();

      // Crear el Payment Sheet con el backend.
      await StripeService.instance.createPaymentSheet(
        amount: amountInCents,
        userId: userId,
      );

      // Presentar el Payment Sheet al usuario.
      final success = await StripeService.instance.presentPaymentSheet();

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Mostrar error al usuario.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el pago: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }
  }

  /// Muestra mensaje cuando Stripe no está configurado.
  void _showNotConfiguredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pagos próximamente. Estamos configurando la pasarela.',
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: MployaColors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  /// Muestra el diálogo de pago exitoso.
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: MployaColors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: MployaColors.teal,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '¡Pago exitoso!',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MployaColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${_product.name} activado correctamente.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MployaColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MployaColors.teal,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: Text(
                  'Volver',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: MployaColors.orange),
        ),
        title: Text(
          'Pasarela de Pago',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.md),

                      // ─── Product Summary Card ──────────────
                      _buildProductCard()
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: -0.1, end: 0),

                      const SizedBox(height: AppSpacing.lg),

                      // ─── Payment Method ────────────────────
                      Text(
                        'Método de pago',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MployaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildPaymentMethods()
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 100.ms)
                          .slideY(begin: 0.05, end: 0),

                      const SizedBox(height: AppSpacing.lg),

                      // ─── Card Form ─────────────────────────
                      Text(
                        'Datos de la tarjeta',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MployaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildCardForm()
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 200.ms)
                          .slideY(begin: 0.05, end: 0),

                      const SizedBox(height: AppSpacing.lg),

                      // ─── Security Info ─────────────────────
                      _buildSecurityBanner()
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 300.ms),

                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Pay Button (sticky bottom) ──────────
            _buildPayButton()
                .animate()
                .fadeIn(duration: 400.ms, delay: 350.ms)
                .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  // ─── Product Summary ───────────────────────────────────────────

  Widget _buildProductCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _product.color,
            _product.color.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: _product.color.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              _product.icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _product.name,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_product.duration != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _product.duration!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'USD',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '\$${_product.price.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Payment Methods ───────────────────────────────────────────

  Widget _buildPaymentMethods() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: List.generate(_paymentMethods.length, (index) {
          final isSelected = _selectedMethod == index;
          final method = _paymentMethods[index];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedMethod = index);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm + 2,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected ? MployaColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      method.$1,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.$2,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? MployaColors.textPrimary
                            : MployaColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Card Form ─────────────────────────────────────────────────

  Widget _buildCardForm() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: MployaColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Nombre en la tarjeta
          _buildFormField(
            controller: _nameController,
            label: 'Nombre en la tarjeta',
            hint: 'Como aparece en la tarjeta',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresá el nombre' : null,
          ),
          const Divider(height: 1, color: MployaColors.borderLight),

          // Número de tarjeta
          _buildFormField(
            controller: _cardNumberController,
            label: 'Número de tarjeta',
            hint: '4242 4242 4242 4242',
            icon: Icons.credit_card_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
            ],
            validator: (v) {
              if (v == null || v.replaceAll(' ', '').length < 16) {
                return 'Ingresá un número válido';
              }
              return null;
            },
          ),
          const Divider(height: 1, color: MployaColors.borderLight),

          // Row: Expiry + CVV
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  controller: _expiryController,
                  label: 'Vencimiento',
                  hint: 'MM/AA',
                  icon: Icons.calendar_today_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ExpiryDateFormatter(),
                  ],
                  validator: (v) => (v == null || v.length < 5)
                      ? 'MM/AA'
                      : null,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: MployaColors.borderLight,
              ),
              Expanded(
                child: _buildFormField(
                  controller: _cvvController,
                  label: 'CVV',
                  hint: '123',
                  icon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (v) => (v == null || v.length < 3)
                      ? 'CVV'
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: MployaColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            color: MployaColors.textTertiary,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: MployaColors.textTertiary.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            icon,
            color: MployaColors.textTertiary,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        validator: validator,
      ),
    );
  }

  // ─── Security Banner ───────────────────────────────────────────

  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.tealLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: MployaColors.teal.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_rounded,
            color: MployaColors.teal,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pago 100% seguro',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.textPrimary,
                  ),
                ),
                Text(
                  'Encriptación SSL · Datos protegidos · Stripe',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MployaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pay Button ────────────────────────────────────────────────

  Widget _buildPayButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: MployaColors.background,
        border: const Border(
          top: BorderSide(color: MployaColors.borderLight),
        ),
      ),
      child: GestureDetector(
        onTap: _isProcessing ? null : _handlePay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: _isProcessing
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: _isProcessing
                ? MployaColors.textTertiary
                : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: _isProcessing
                ? null
                : [
                    BoxShadow(
                      color:
                          const Color(0xFFF97316).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: _isProcessing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Procesando...',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Pagar USD \$${_product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Card Number Formatter ─────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) {
      return oldValue;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

// ─── Expiry Date Formatter ─────────────────────────────────────

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length > 4) {
      return oldValue;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
