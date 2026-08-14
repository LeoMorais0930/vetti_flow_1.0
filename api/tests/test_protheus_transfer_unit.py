from types import SimpleNamespace

from app import protheus


def test_transferencia_lanca_re4_de4_e_move_saldo(monkeypatch):
    movimentos_sd3 = []
    movimentos_sb2 = []

    monkeypatch.setattr(protheus, "_existe_produto", lambda *args: True)
    monkeypatch.setattr(
        protheus,
        "_saldo",
        lambda _conn, _filial, _produto, local: {
            "b2_qatu": 100 if local == "01" else 10,
            "b2_qemp": 0,
        },
    )
    monkeypatch.setattr(
        protheus.db,
        "proximo_recno",
        lambda _conn, _tabela: 123,
    )
    monkeypatch.setattr(
        protheus,
        "_inserir_movimento_sd3",
        lambda _conn, **kwargs: movimentos_sd3.append(kwargs),
    )
    monkeypatch.setattr(
        protheus,
        "_mexer_saldo",
        lambda _conn, filial, produto, local, **kwargs: movimentos_sb2.append(
            {
                "filial": filial,
                "produto": produto,
                "local": local,
                **kwargs,
            }
        ),
    )

    mutacao = SimpleNamespace(
        filial="04",
        payload=SimpleNamespace(
            produto="100-003",
            quantidade=12,
            localOrigem="01",
            localDestino="05",
            op="01595801001",
        ),
    )

    ref, antes = protheus.transferir(object(), mutacao)

    assert ref == "SD3:TR0000123"
    assert antes["origem"]["b2_qatu"] == 100
    assert [m["cf"] for m in movimentos_sd3] == ["RE4", "DE4"]
    assert [m["local"] for m in movimentos_sd3] == ["01", "05"]
    assert all(m["doc"] == "TR0000123" for m in movimentos_sd3)
    assert movimentos_sb2 == [
        {"filial": "04", "produto": "100-003", "local": "01", "qatu": -12},
        {"filial": "04", "produto": "100-003", "local": "05", "qatu": 12},
    ]
