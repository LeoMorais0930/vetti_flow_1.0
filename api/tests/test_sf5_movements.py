import pytest

from app import config, protheus


class _OneRow:
    def __init__(self, row):
        self.row = row

    def fetchone(self):
        return self.row


class _FakeConn:
    def __init__(self, sf5_rows=None):
        self.sf5_rows = list(sf5_rows or [])
        self.queries = []

    def execute(self, sql, params=()):
        self.queries.append((sql, params))
        if "to_regclass" in sql:
            return _OneRow({"rel": "sf5010"})
        return _OneRow(self.sf5_rows.pop(0) if self.sf5_rows else None)


def _set_mapping(monkeypatch, **valores):
    mapping = {
        "PR0": "",
        "PR1": "",
        "RE1": "",
        "RE4": "",
        "DE4": "",
        "ER0": "",
        "ER1": "",
    }
    mapping.update(valores)
    monkeypatch.setattr(config, "SF5_TM_BY_CF", mapping)


def test_modo_local_permite_sd3_sem_tm_quando_sf5_nao_esta_configurada(monkeypatch):
    monkeypatch.setattr(config, "REQUIRE_SF5_MOVEMENTS", False)
    _set_mapping(monkeypatch)
    conn = _FakeConn()

    campos = protheus._campos_movimento_sd3(conn, "04", "RE1")

    assert campos == {"d3_cf": "RE1"}
    assert conn.queries == []


def test_modo_servidor_exige_tm_configurado_para_o_cf(monkeypatch):
    monkeypatch.setattr(config, "REQUIRE_SF5_MOVEMENTS", True)
    _set_mapping(monkeypatch)

    with pytest.raises(protheus.RecusaProtheus, match="VF_TM_RE1"):
        protheus._campos_movimento_sd3(_FakeConn(), "04", "RE1")


def test_modo_servidor_aceita_tm_quando_sf5_confirma_tipo(monkeypatch):
    monkeypatch.setattr(config, "REQUIRE_SF5_MOVEMENTS", True)
    _set_mapping(monkeypatch, RE1="501")
    conn = _FakeConn([{"codigo": "501", "tipo": "R", "descricao": "Req auto"}])

    campos = protheus._campos_movimento_sd3(conn, "04", "RE1")

    assert campos == {"d3_cf": "RE1", "d3_tm": "501"}


def test_modo_servidor_recusa_tm_com_tipo_sf5_incompativel(monkeypatch):
    monkeypatch.setattr(config, "REQUIRE_SF5_MOVEMENTS", True)
    _set_mapping(monkeypatch, RE1="003")
    conn = _FakeConn([{"codigo": "003", "tipo": "D", "descricao": "Devolucao"}])

    with pytest.raises(protheus.RecusaProtheus, match="RE1 exige tipo R"):
        protheus._campos_movimento_sd3(conn, "04", "RE1")
