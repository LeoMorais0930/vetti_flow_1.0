"""O portao de entrada da API.

Esta API abre OP e da baixa no Protheus. O que estes testes fixam e que ela nao
atende a rede sem credencial — nem quando alguem esquece de configurar o token.
"""
import importlib

import pytest
from fastapi.testclient import TestClient

from app import config


@pytest.fixture
def cliente_com_token(monkeypatch):
    monkeypatch.setattr(config, "API_TOKEN", "token-de-teste")
    from app import main

    with TestClient(main.app) as c:
        yield c


@pytest.fixture
def cliente_sem_token(monkeypatch):
    monkeypatch.setattr(config, "API_TOKEN", "")
    from app import main

    with TestClient(main.app) as c:
        yield c


def test_sem_cabecalho_a_api_recusa(cliente_com_token):
    resposta = cliente_com_token.get("/api/v1/health")
    assert resposta.status_code == 401
    assert "X-API-Token" in resposta.json()["detail"]


def test_token_errado_recusa(cliente_com_token):
    resposta = cliente_com_token.get(
        "/api/v1/health", headers={"X-API-Token": "token-errado"}
    )
    assert resposta.status_code == 401


def test_token_certo_passa(cliente_com_token):
    resposta = cliente_com_token.get(
        "/api/v1/health", headers={"X-API-Token": "token-de-teste"}
    )
    assert resposta.status_code == 200
    assert resposta.json()["ok"] is True


def test_mutations_tambem_exige_token(cliente_com_token):
    """O 401 vale para a rota que grava, nao so para a de diagnostico."""
    resposta = cliente_com_token.post("/api/v1/mutations", json={"mutations": []})
    assert resposta.status_code == 401


def test_sem_token_configurado_o_loopback_passa(cliente_sem_token):
    assert cliente_sem_token.get("/api/v1/health").status_code == 200


def test_sem_token_configurado_a_rede_e_recusada(monkeypatch):
    """Esquecer `VF_API_TOKEN` fecha a API, em vez de abrir o Protheus."""
    monkeypatch.setattr(config, "API_TOKEN", "")
    from app import main

    # `client` troca o endereco de origem da requisicao: e a maquina do
    # Leonardo batendo, nao o loopback.
    with TestClient(main.app, client=("10.36.0.37", 5000)) as remoto:
        resposta = remoto.get("/api/v1/health")

    assert resposta.status_code == 503
    assert "VF_API_TOKEN" in resposta.json()["detail"]


def test_preflight_do_cors_nao_precisa_de_token(cliente_com_token):
    """Sem isso o navegador reporta erro de origem em vez do 401."""
    resposta = cliente_com_token.options(
        "/api/v1/mutations",
        headers={
            "Origin": "http://10.36.0.37:8080",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "x-api-token",
        },
    )
    assert resposta.status_code == 200
    assert "access-control-allow-origin" in resposta.headers
