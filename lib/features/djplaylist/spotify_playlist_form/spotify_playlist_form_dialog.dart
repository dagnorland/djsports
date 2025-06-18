import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/features/djplaylist/spotify_playlist_form/models/spotify_playlist_form_data.model.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/spotify_playlist_form_cubit.dart';

class SpotifyImportFormDialog extends StatelessWidget {
  const SpotifyImportFormDialog._({
    required this.isNew,
    required this.formData,
    required this.type,
  });

  final bool isNew;
  final SpotifyImportFormData formData;
  final DJPlaylistType type;

  static Future<DJPlaylist?> openCreate(
    BuildContext context, {
    required String playlistId,
    required DJPlaylistType type,
    SpotifyImportFormData? initialFormData,
  }) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider(
        create: (context) => SpotifyImportFormCubit(
          playlistId: playlistId,
          type: type,
          customerRepository: context.read(),
        ),
        child: SpotifyImportFormDialog._(
          isNew: true,
          formData: initialFormData ??
              SpotifyImportFormData(
                type: type,
              ),
          type: type,
        ),
      ),
    );
  }

  static Future<DJPlaylist?> openEdit(
    BuildContext context, {
    required String playlistId,
    required DJPlaylist playlist,
  }) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider(
        create: (context) => SpotifyImportFormCubit(
          playlistId: playlistId,
          type: playlist.type,
          customerRepository: context.read(),
        ),
        child: SpotifyImportFormDialog._(
          isNew: false,
          formData: SpotifyImportFormData.fromDJPlaylist(playlist),
          type: DJPlaylistType.values.byName(playlist.type),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlobalDialog(
      width: 650,
      title: isNew
          ? '${$t.create} ${type.label.toLowerCase()}'
          : '${$t.edit} ${type.label.toLowerCase()}',
      child: BlocListener<CustomerAddressFormCubit, CustomerAddressFormState>(
        listener: (context, state) {
          state.newCustomerAddress.when(
            isComplete: (customerAddress) {
              Navigator.of(context).pop(customerAddress);
              final message = isNew
                  ? $t.customerAddressCreatedBanner
                  : $t.customerAddressUpdatedBanner;

              GlobalBanner.instance.showSuccessBanner(
                context: context,
                message: message,
              );
            },
            isError: (error) => GlobalBanner.instance
                .showErrorBanner(context: context, message: error!),
            isInProgress: context.globalLoader.show,
            notInProgress: context.globalLoader.hide,
          );
        },
        child: AddressFormWidget(
          formData: formData,
          onSubmitted: (formData) => context
              .read<CustomerAddressFormCubit>()
              .onFormSubmitted(formData),
          initializeAsCompanyAddress: initializeAsCompanyAddress ?? false,
        ),
      ),
    );
  }
}
