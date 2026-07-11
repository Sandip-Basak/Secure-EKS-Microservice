from django.urls import path, include
from rest_framework.routers import SimpleRouter
from .views import CategoryViewSet, ProductViewSet
from django.http import JsonResponse

# 1. Initialize the clean, minimal router
router = SimpleRouter()
router.register(r'categories', CategoryViewSet, basename='category')
router.register(r'products', ProductViewSet, basename='product')

# 2. Ultra-lightweight health view for Kubernetes probes
def kubernetes_health_check(request):
    """
    Exposed endpoint for EKS Kubelet to verify container health.
    Must bypass all multi-tenant and authentication filters.
    """
    return JsonResponse({"status": "healthy"}, status=200)

# 3. Explicitly map the URLs
urlpatterns = [
    # This path sits OUTSIDE the router so it doesn't expect standard DRF behaviors
    path('healthz', kubernetes_health_check, name='health_check'),
    
    # Include all auto-generated CRUD routes for categories and products
    path('', include(router.urls)),
]