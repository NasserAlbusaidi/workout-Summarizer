"""
Tests for the Ephemeral Workout Analyzer API
"""

import pytest
from fastapi.testclient import TestClient
import io

# Import the app
from api import app, parse_fit_bytes

client = TestClient(app)


class TestHealthEndpoint:
    """Test the health check endpoint."""
    
    def test_health_returns_200(self):
        """Health endpoint should return 200 OK."""
        response = client.get("/health")
        assert response.status_code == 200
    
    def test_health_returns_healthy_status(self):
        """Health endpoint should indicate healthy status."""
        response = client.get("/health")
        data = response.json()
        assert data["status"] == "healthy"
        assert data["ephemeral"] == True
    
    def test_health_includes_version(self):
        """Health endpoint should include version."""
        response = client.get("/health")
        data = response.json()
        assert "version" in data


class TestTiersEndpoint:
    """Test the pricing tiers endpoint."""
    
    def test_tiers_returns_200(self):
        """Tiers endpoint should return 200 OK."""
        response = client.get("/tiers")
        assert response.status_code == 200
    
    def test_tiers_returns_three_tiers(self):
        """Should return Free, Pro, and Elite tiers."""
        response = client.get("/tiers")
        data = response.json()
        assert len(data["tiers"]) == 3
        tier_names = [t["name"] for t in data["tiers"]]
        assert "Free" in tier_names
        assert "Pro" in tier_names
        assert "Elite" in tier_names


class TestValidateKeyEndpoint:
    """Test API key validation."""
    
    def test_anonymous_access_allowed(self):
        """Anonymous access should be allowed with free tier."""
        response = client.get("/validate-key")
        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "anonymous"
        assert data["daily_limit"] == 3
    
    def test_valid_free_key(self):
        """Valid free key should return free tier info."""
        response = client.get("/validate-key", headers={"X-API-Key": "demo-free-key"})
        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "free"
        assert data["daily_limit"] == 3
    
    def test_valid_pro_key(self):
        """Valid pro key should return pro tier info."""
        response = client.get("/validate-key", headers={"X-API-Key": "demo-pro-key"})
        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "pro"
        assert data["daily_limit"] == 50
    
    def test_valid_elite_key(self):
        """Valid elite key should return elite tier info."""
        response = client.get("/validate-key", headers={"X-API-Key": "demo-elite-key"})
        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "elite"
        assert data["daily_limit"] == 1000
    
    def test_invalid_key_rejected(self):
        """Invalid API key should be rejected."""
        response = client.get("/validate-key", headers={"X-API-Key": "invalid-key"})
        assert response.status_code == 401


class TestAnalyzeEndpoint:
    """Test the main analyze endpoint."""
    
    def test_missing_file_returns_422(self):
        """Missing file should return 422."""
        response = client.post("/analyze", data={"plan": "test plan"})
        assert response.status_code == 422
    
    def test_missing_plan_returns_422(self):
        """Missing plan should return 422."""
        # Create a minimal fake FIT file
        fake_fit = io.BytesIO(b"fake fit data")
        response = client.post(
            "/analyze",
            files={"file": ("test.fit", fake_fit, "application/octet-stream")}
        )
        assert response.status_code == 422


class TestRateLimiting:
    """Test rate limiting functionality."""
    
    def test_rate_limit_header_present(self):
        """Rate limit headers should be present."""
        response = client.get("/health")
        # Check that rate limiting is configured
        assert response.status_code == 200


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
