import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/utils/utils.dart';

const _kGroupEmojis = [
  '🏠',
  '👨‍👩‍👧‍👦',
  '💰',
  '🎓',
  '🕌',
  '✈️',
  '🚗',
  '🏥',
  '🎁',
  '🍽️',
  '⚽',
  '🏢',
  '🌴',
  '🐱',
  '🎉',
  '📚',
];
const _kDueDays = [1, 5, 10, 15, 25, 28];

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController(text: '30.00');
  final _initialController = TextEditingController(text: '0.00');

  bool _isMonthly = true; // Monthly fund vs One-off split
  int _reminderDay = 28;
  String _emoji = '🏠';
  File? _photo; // chosen locally; uploaded after group exists
  final _emailController = TextEditingController();
  final List<String> _invites = []; // emails to invite after creation
  bool _isLoading = false;

  static final _emailRe = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  bool get _emailValid => _emailRe.hasMatch(_emailController.text.trim());
  void _addInvite() {
    final e = _emailController.text.trim().toLowerCase();
    if (!_emailRe.hasMatch(e) || _invites.contains(e)) return;
    setState(() {
      _invites.add(e);
      _emailController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    // Re-run canCreate on name/amount edits.
    _nameController.addListener(_onChanged);
    _amountController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _amountController.dispose();
    _initialController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _canCreate {
    if (_nameController.text.trim().length < 3) return false;
    if (_isMonthly) {
      final v = double.tryParse(_amountController.text.trim());
      if (v == null || v <= 0) return false;
    }
    return !_isLoading;
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  Widget _ownerInitials(String initials) => Container(
    color: DT.primarySoft,
    alignment: Alignment.center,
    child: Text(
      initials.isNotEmpty ? initials : '?',
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: DT.primary,
      ),
    ),
  );

  int get _memberCount => 1; // creator; others invited after creation
  double get _perMember {
    final v = double.tryParse(_amountController.text.trim()) ?? 0;
    return _memberCount > 0 ? v / _memberCount : 0;
  }

  Future<void> _pickIcon() async {
    final result = await showModalBottomSheet<_IconResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) =>
              _GroupIconSheet(currentEmoji: _emoji, hasPhoto: _photo != null),
    );
    if (result == null || !mounted) return;
    if (result.emoji != null) {
      setState(() {
        _emoji = result.emoji!;
        _photo = null;
      });
    } else if (result.remove) {
      setState(() => _photo = null);
    } else if (result.pickPhoto) {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null && mounted) setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _create() async {
    if (!_canCreate) return;
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    final userEmail =
        ref.read(authControllerProvider.notifier).currentUser?.email;
    if (userId == null) {
      showSnackBar(context, 'User not logged in', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final profile = await ref
          .read(profileServiceProvider)
          .getUserProfile(userId);
      final groupService = ref.read(groupServiceProvider);

      final groupId = await groupService.createGroup(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        createdBy: userId,
        creatorName: profile?.name ?? 'Unknown',
        creatorEmail: userEmail,
        monthlyAmount:
            _isMonthly ? double.parse(_amountController.text.trim()) : 0.0,
        initialBalance: double.tryParse(_initialController.text.trim()) ?? 0.0,
        reminderDay: _reminderDay,
        iconEmoji: _photo == null ? _emoji : null,
      );

      // Upload photo now that the group doc exists (Storage rules need it).
      if (_photo != null) {
        try {
          final url = await ref
              .read(storageServiceProvider)
              .uploadGroupImage(groupId: groupId, file: _photo!);
          await groupService.setGroupIcon(groupId: groupId, iconUrl: url);
        } catch (_) {
          /* keep the group even if the photo upload fails */
        }
      }

      // Resolve invited emails to real users and add them. Emails with no
      // matching account are collected and reported (they can join by link).
      final profileService = ref.read(profileServiceProvider);
      final notFound = <String>[];
      for (final email in _invites) {
        try {
          final uid = await profileService.findUserId(email);
          if (uid == null) {
            notFound.add(email);
            continue;
          }
          final p = await profileService.getUserProfile(uid);
          await groupService.addMemberToGroup(
            groupId: groupId,
            userId: uid,
            userName: p?.name ?? 'Member',
            userEmail: p?.email ?? email,
          );
        } catch (_) {
          notFound.add(email);
        }
      }

      if (mounted) {
        final added = _invites.length - notFound.length;
        final msg =
            _invites.isEmpty
                ? 'Group created — invite members from the group page'
                : notFound.isEmpty
                ? 'Group created · $added member${added == 1 ? '' : 's'} added'
                : 'Group created · $added added · ${notFound.length} not on DuitKita yet';
        showSnackBar(context, msg);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to create group: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider.notifier).currentUser;
    final myProfile =
        me != null
            ? ref.watch(userProfileStreamProvider(me.uid)).valueOrNull
            : null;
    final myName =
        myProfile?.name ??
        me?.displayName ??
        me?.email?.split('@').first ??
        'You';
    final myPhoto = myProfile?.profileImageUrl;
    final myInitials =
        myName
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _SquareIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create group',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: DT.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Split bills with people you trust',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: DT.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identity card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: DT.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: DT.border),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickIcon,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: DT.catGroupsSoft,
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                  child:
                                      _photo != null
                                          ? Image.file(
                                            _photo!,
                                            width: 86,
                                            height: 86,
                                            fit: BoxFit.cover,
                                          )
                                          : Text(
                                            _emoji,
                                            style: const TextStyle(
                                              fontSize: 46,
                                            ),
                                          ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: DT.text,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: DT.surface,
                                        width: 3,
                                      ),
                                    ),
                                    child: Icon(
                                      _photo != null
                                          ? Icons.photo_camera_outlined
                                          : Icons.edit_outlined,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            maxLength: 50,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: DT.text,
                              letterSpacing: -0.4,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Group name',
                              hintStyle: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: DT.textTertiary,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descController,
                            maxLength: 200,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: DT.text,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              isDense: true,
                              contentPadding: const EdgeInsets.fromLTRB(
                                36,
                                11,
                                12,
                                11,
                              ),
                              prefixIcon: const Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: DT.textTertiary,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 36,
                              ),
                              filled: true,
                              fillColor: DT.surfaceAlt,
                              hintText: 'Add a short description',
                              hintStyle: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: DT.textTertiary,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide: const BorderSide(color: DT.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide: const BorderSide(color: DT.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Group type
                    _Label('GROUP TYPE'),
                    Row(
                      children: [
                        Expanded(
                          child: _TypeCard(
                            icon: Icons.calendar_today_outlined,
                            title: 'Monthly fund',
                            sub: 'Recurring contribution each month',
                            active: _isMonthly,
                            onTap: () => setState(() => _isMonthly = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TypeCard(
                            icon: Icons.auto_awesome_outlined,
                            title: 'One-off split',
                            sub: 'Split costs as they come up',
                            active: !_isMonthly,
                            onTap: () => setState(() => _isMonthly = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Contribution (monthly only)
                    if (_isMonthly) ...[
                      _Label('CONTRIBUTION'),
                      Container(
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: DT.border),
                        ),
                        child: Column(
                          children: [
                            _AmountRow(
                              label: 'Monthly amount',
                              controller: _amountController,
                            ),
                            const Divider(height: 1, color: DT.border),
                            _AmountRow(
                              label: 'Initial amount',
                              hint: 'Starting balance (optional)',
                              controller: _initialController,
                            ),
                            const Divider(height: 1, color: DT.border),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Due day',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: DT.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children:
                                        _kDueDays.map((day) {
                                          final active = _reminderDay == day;
                                          return GestureDetector(
                                            onTap:
                                                () => setState(
                                                  () => _reminderDay = day,
                                                ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 13,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    active
                                                        ? DT.text
                                                        : DT.surfaceAlt,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color:
                                                      active
                                                          ? DT.text
                                                          : DT.border,
                                                ),
                                              ),
                                              child: Text(
                                                _ordinal(day),
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      active
                                                          ? Colors.white
                                                          : DT.text,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: DT.border),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Text(
                                    'Currency',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: DT.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '🇲🇾 MYR · RM',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: DT.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Split preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: DT.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.monetization_on_outlined,
                              size: 18,
                              color: DT.accentDeep,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: DT.text,
                                    height: 1.4,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Split evenly — '),
                                    TextSpan(
                                      text:
                                          'RM ${_perMember.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: ' each as members join',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: DT.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: DT.catGroupsSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_outlined,
                                size: 17,
                                color: DT.catGroups,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No fixed amount — add expenses as they happen and each share is split between members.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: DT.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Members — creator is the first member; others invited by email
                    _Label('MEMBERS'),
                    Container(
                      decoration: BoxDecoration(
                        color: DT.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DT.border),
                      ),
                      child: Column(
                        children: [
                          // Group owner (you)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: DT.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child:
                                        (myPhoto != null && myPhoto.isNotEmpty)
                                            ? Image.network(
                                              myPhoto,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) =>
                                                      _ownerInitials(
                                                        myInitials,
                                                      ),
                                            )
                                            : _ownerInitials(myInitials),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              myName,
                                              style: GoogleFonts.manrope(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: DT.text,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: DT.accentSoft,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'You',
                                              style: GoogleFonts.manrope(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: DT.accentDeep,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '👑 Admin · group owner',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: DT.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final email in _invites)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: DT.border),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: DT.surfaceAlt,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      size: 18,
                                      color: DT.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          email,
                                          style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: DT.text,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Will be added if they have an account',
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: DT.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap:
                                        () => setState(
                                          () => _invites.remove(email),
                                        ),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: DT.surfaceAlt,
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(color: DT.border),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 15,
                                        color: DT.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (_) => setState(() {}),
                                    onSubmitted: (_) => _addInvite(),
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: DT.text,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: 'friend@email.com',
                                      hintStyle: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: DT.textTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _emailValid ? _addInvite : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _emailValid ? DT.text : DT.surfaceAlt,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Add',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            _emailValid
                                                ? Colors.white
                                                : DT.textTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You can also invite by QR code or link after the group is created.',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: DT.textTertiary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: DT.surface,
                border: Border(top: BorderSide(color: DT.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _canCreate ? _create : null,
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _isLoading ? '' : 'Create group',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: DT.borderStrong,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── small building blocks ──────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: DT.textSecondary,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DT.border),
      ),
      child: Icon(icon, size: 20, color: DT.text),
    ),
  );
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool active;
  final VoidCallback onTap;
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? DT.accentSoft : DT.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? DT.accent : DT.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? DT.surface : DT.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 17,
              color: active ? DT.accentDeep : DT.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: DT.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: DT.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  const _AmountRow({required this.label, this.hint, required this.controller});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DT.textSecondary,
                ),
              ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    hint!,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: DT.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Text(
          'RM',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: DT.textTertiary,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 96,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: DT.text,
              letterSpacing: -0.2,
            ),
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── icon picker sheet (self-contained; _-private to this file) ───────────────
class _IconResult {
  final String? emoji;
  final bool pickPhoto;
  final bool remove;
  const _IconResult({this.emoji, this.pickPhoto = false, this.remove = false});
}

class _GroupIconSheet extends StatelessWidget {
  final String currentEmoji;
  final bool hasPhoto;
  const _GroupIconSheet({required this.currentEmoji, required this.hasPhoto});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: DT.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: DT.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group icon',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DT.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pick an emoji or upload a photo',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: DT.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap:
              () => Navigator.pop(context, const _IconResult(pickPhoto: true)),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DT.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DT.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: DT.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    size: 20,
                    color: DT.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPhoto ? 'Change photo' : 'Upload a photo',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: DT.text,
                        ),
                      ),
                      Text(
                        'Square images look best',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: DT.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: DT.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (hasPhoto)
          GestureDetector(
            onTap:
                () => Navigator.pop(context, const _IconResult(remove: true)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
              child: Text(
                'Remove photo',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DT.danger,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'EMOJI',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: DT.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _kGroupEmojis.length,
          itemBuilder: (_, i) {
            final e = _kGroupEmojis[i];
            final active = !hasPhoto && e == currentEmoji;
            return GestureDetector(
              onTap: () => Navigator.pop(context, _IconResult(emoji: e)),
              child: Container(
                decoration: BoxDecoration(
                  color: active ? DT.catGroupsSoft : DT.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? DT.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(e, style: const TextStyle(fontSize: 24)),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
