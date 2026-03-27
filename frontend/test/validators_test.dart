import 'package:flutter_test/flutter_test.dart';
import 'package:amino_clone/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('required', () {
      test('retorna erro para string vazia', () {
        expect(Validators.required()(''), isNotNull);
      });

      test('retorna erro para null', () {
        expect(Validators.required()(null), isNotNull);
      });

      test('retorna erro para string com apenas espaços', () {
        expect(Validators.required()('   '), isNotNull);
      });

      test('retorna null para string válida', () {
        expect(Validators.required()('hello'), isNull);
      });

      test('aceita mensagem customizada', () {
        expect(Validators.required('Campo X é obrigatório')(''), 'Campo X é obrigatório');
      });
    });

    group('minLength', () {
      test('retorna erro para string curta', () {
        expect(Validators.minLength(5)('abc'), isNotNull);
      });

      test('retorna null para string com comprimento exato', () {
        expect(Validators.minLength(5)('abcde'), isNull);
      });

      test('retorna null para string longa', () {
        expect(Validators.minLength(5)('abcdefgh'), isNull);
      });

      test('retorna erro para null', () {
        expect(Validators.minLength(3)(null), isNotNull);
      });
    });

    group('maxLength', () {
      test('retorna erro para string longa', () {
        expect(Validators.maxLength(5)('abcdefgh'), isNotNull);
      });

      test('retorna null para string com comprimento exato', () {
        expect(Validators.maxLength(5)('abcde'), isNull);
      });

      test('retorna null para string curta', () {
        expect(Validators.maxLength(5)('abc'), isNull);
      });

      test('retorna null para null', () {
        expect(Validators.maxLength(5)(null), isNull);
      });
    });

    group('email', () {
      test('retorna erro para email inválido', () {
        expect(Validators.email()('notanemail'), isNotNull);
        expect(Validators.email()('missing@'), isNotNull);
        expect(Validators.email()('@missing.com'), isNotNull);
        expect(Validators.email()('no spaces@email.com'), isNotNull);
      });

      test('retorna null para email válido', () {
        expect(Validators.email()('user@example.com'), isNull);
        expect(Validators.email()('user.name@domain.co'), isNull);
        expect(Validators.email()('user+tag@gmail.com'), isNull);
      });

      test('retorna erro para vazio', () {
        expect(Validators.email()(''), isNotNull);
        expect(Validators.email()(null), isNotNull);
      });
    });

    group('password', () {
      test('retorna erro para senha curta', () {
        expect(Validators.password()('Ab1'), isNotNull);
      });

      test('retorna erro para senha sem maiúscula', () {
        expect(Validators.password()('abcdefg1'), isNotNull);
      });

      test('retorna erro para senha sem minúscula', () {
        expect(Validators.password()('ABCDEFG1'), isNotNull);
      });

      test('retorna erro para senha sem número', () {
        expect(Validators.password()('Abcdefgh'), isNotNull);
      });

      test('retorna null para senha forte', () {
        expect(Validators.password()('Abcdefg1'), isNull);
        expect(Validators.password()('MyP@ss123'), isNull);
      });
    });

    group('confirmPassword', () {
      test('retorna erro quando senhas não coincidem', () {
        expect(Validators.confirmPassword('abc123')('xyz789'), isNotNull);
      });

      test('retorna null quando senhas coincidem', () {
        expect(Validators.confirmPassword('abc123')('abc123'), isNull);
      });
    });

    group('nickname', () {
      test('retorna erro para nickname curto', () {
        expect(Validators.nickname()('ab'), isNotNull);
      });

      test('retorna erro para nickname longo', () {
        expect(Validators.nickname()('a' * 21), isNotNull);
      });

      test('retorna erro para nickname com caracteres especiais', () {
        expect(Validators.nickname()('user name'), isNotNull);
        expect(Validators.nickname()('user@name'), isNotNull);
        expect(Validators.nickname()('user-name'), isNotNull);
      });

      test('retorna null para nickname válido', () {
        expect(Validators.nickname()('user_123'), isNull);
        expect(Validators.nickname()('NexusUser'), isNull);
        expect(Validators.nickname()('abc'), isNull);
      });
    });

    group('url', () {
      test('retorna null para URL vazia (opcional)', () {
        expect(Validators.url()(''), isNull);
        expect(Validators.url()(null), isNull);
      });

      test('retorna erro para URL inválida', () {
        expect(Validators.url()('not a url'), isNotNull);
        expect(Validators.url()('ftp://wrong.com'), isNotNull);
      });

      test('retorna null para URL válida', () {
        expect(Validators.url()('https://example.com'), isNull);
        expect(Validators.url()('http://sub.domain.com/path?q=1'), isNull);
      });
    });

    group('positiveInt', () {
      test('retorna erro para zero', () {
        expect(Validators.positiveInt()('0'), isNotNull);
      });

      test('retorna erro para negativo', () {
        expect(Validators.positiveInt()('-5'), isNotNull);
      });

      test('retorna erro para não-número', () {
        expect(Validators.positiveInt()('abc'), isNotNull);
      });

      test('retorna null para inteiro positivo', () {
        expect(Validators.positiveInt()('42'), isNull);
        expect(Validators.positiveInt()('1'), isNull);
      });
    });

    group('numberRange', () {
      test('retorna erro fora do range', () {
        expect(Validators.numberRange(1, 100)('0'), isNotNull);
        expect(Validators.numberRange(1, 100)('101'), isNotNull);
      });

      test('retorna null dentro do range', () {
        expect(Validators.numberRange(1, 100)('1'), isNull);
        expect(Validators.numberRange(1, 100)('50'), isNull);
        expect(Validators.numberRange(1, 100)('100'), isNull);
      });
    });

    group('compose', () {
      test('retorna primeiro erro encontrado', () {
        final validator = Validators.compose([
          Validators.required(),
          Validators.minLength(5),
        ]);
        expect(validator(''), isNotNull); // required falha primeiro
        expect(validator('ab'), isNotNull); // minLength falha
        expect(validator('abcde'), isNull); // ambos passam
      });
    });
  });
}
