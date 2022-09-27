

typedef ActionFunc = void Function();

typedef Handler<T> = void Function(T);
typedef BiHandler<T1, T2> = void Function(T1, T2);
typedef TriHandler<T1, T2, T3> = void Function(T1, T2, T3);

typedef Mapper<I, O> = O Function(I);
typedef BiMapper<T1, T2, R> = R Function(T1, T2);
typedef TriMapper<T1, T2, T3, R> = R Function(T1, T2, T3);

typedef QuaMapper<T1, T2, T3, T4, R> = R Function(T1, T2, T3, T4);

typedef Supplier<T> = T Function();