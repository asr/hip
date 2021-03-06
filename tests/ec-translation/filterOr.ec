data List a = Cons a (List a) | Nil;

filterOr p q xs = case xs of
    { Cons y ys | p y -> Cons y (filterOr p q ys)
    ; Cons y ys | q y -> Cons y (filterOr p q ys)
    ; Cons y ys       -> filterOr p q ys
    ; Nil             -> Nil
    };

