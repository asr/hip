data List a = Cons a (List a) | Nil;

if b t f = case b of
         { True -> t
         ; _    -> f
         };

deleteAdjacent eq xs = case xs of
   { Cons x (Cons y ys) -> if (eq x y) (deleteAdjacent eq (Cons x ys))
                                     (Cons x (deleteAdjacent eq (Cons y ys)))
   ; d -> d
   };

