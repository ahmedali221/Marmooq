import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:marmooq/features/products/model/product_failure.dart';
import 'package:marmooq/features/products/model/products_repository.dart';
import 'package:marmooq/features/products/view_model/products_event.dart';
import 'package:marmooq/features/products/view_model/products_state.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository repository;

  ProductsBloc(this.repository) : super(ProductsInitial()) {
    on<FetchProductsEvent>(_onFetchProducts);
    on<LoadMoreProductsEvent>(_onLoadMoreProducts);
  }

  Future<void> _onFetchProducts(
    FetchProductsEvent event,
    Emitter<ProductsState> emit,
  ) async {
    emit(ProductsLoading());
    final Either<ProductFailure, List<Map<String, dynamic>>> result =
        await repository.getProducts(
          forceRefresh: event.forceRefresh,
          page: event.page,
          limit: event.limit,
        );
    result.fold(
      (failure) => emit(ProductsError(failure)),
      (collections) => emit(
        ProductsLoaded(
          collections: collections,
          currentPage: event.page,
          hasMore: collections.isNotEmpty,
        ),
      ),
    );
  }

  Future<void> _onLoadMoreProducts(
    LoadMoreProductsEvent event,
    Emitter<ProductsState> emit,
  ) async {
    if (state is ProductsLoaded) {
      final currentState = state as ProductsLoaded;

      if (!currentState.hasMore || currentState.isLoadingMore) {
        return;
      }

      emit(currentState.copyWith(isLoadingMore: true));

      final Either<ProductFailure, List<Map<String, dynamic>>> result =
          await repository.loadMoreProducts(
            page: event.page,
            limit: event.limit,
          );

      result.fold((failure) => emit(ProductsError(failure)), (newCollections) {
        // Merge new collections with existing ones
        final Map<String, Map<String, dynamic>> mergedCollections = {};

        // Add existing collections
        for (final collection in currentState.collections) {
          final key = collection['collectionId'] as String;
          mergedCollections[key] = Map<String, dynamic>.from(collection);
        }

        // Add or merge new collections
        for (final collection in newCollections) {
          final key = collection['collectionId'] as String;
          if (mergedCollections.containsKey(key)) {
            // Merge products
            final existingProducts =
                mergedCollections[key]!['products'] as List;
            final newProducts = collection['products'] as List;
            mergedCollections[key]!['products'] = [
              ...existingProducts,
              ...newProducts,
            ];
          } else {
            mergedCollections[key] = Map<String, dynamic>.from(collection);
          }
        }

        final updatedCollections = mergedCollections.values.toList();
        final hasMore =
            newCollections.isNotEmpty &&
            newCollections.any(
              (collection) => (collection['products'] as List).isNotEmpty,
            );

        emit(
          ProductsLoaded(
            collections: updatedCollections,
            currentPage: event.page,
            hasMore: hasMore,
            isLoadingMore: false,
          ),
        );
      });
    }
  }
}
