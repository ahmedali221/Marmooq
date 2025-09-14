import 'package:equatable/equatable.dart';
import 'package:traincode/features/products/model/product_failure.dart';

abstract class ProductsState extends Equatable {
  @override
  List<Object> get props => [];
}

class ProductsInitial extends ProductsState {}

class ProductsLoading extends ProductsState {}

class ProductsLoaded extends ProductsState {
  final List<Map<String, dynamic>> collections;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;

  ProductsLoaded({
    required this.collections,
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  ProductsLoaded copyWith({
    List<Map<String, dynamic>>? collections,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ProductsLoaded(
      collections: collections ?? this.collections,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object> get props => [collections, currentPage, hasMore, isLoadingMore];
}

class ProductsError extends ProductsState {
  final ProductFailure failure;

  ProductsError(this.failure);

  @override
  List<Object> get props => [failure];
}
