import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:traincode/features/products/model/product_failure.dart';
import 'package:traincode/features/products/model/product_model.dart';
import 'package:traincode/features/products/model/products_repository.dart';
import 'package:traincode/features/products/view_model/products_event.dart';
import 'package:traincode/features/products/view_model/products_state.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository repository;

  ProductsBloc(this.repository) : super(ProductsInitial()) {
    on<FetchProductsEvent>(_onFetchProducts);
  }

  Future<void> _onFetchProducts(FetchProductsEvent event, Emitter<ProductsState> emit) async {
    emit(ProductsLoading());
    final Either<ProductFailure, List<Product>> result = await repository.getProducts();
    result.fold(
      (failure) => emit(ProductsError(failure)),
      (products) => emit(ProductsLoaded(products)),
    );
  }
}