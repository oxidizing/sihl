exception DatabaseException(string);

let abort = reason => raise(DatabaseException(reason));
