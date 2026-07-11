from rest_framework import viewsets
from .models import Category, Product
from .serializers import CategorySerializer, ProductSerializer
from .permissions import TrustedGatewayAuthentication

class MultiTenantBaseViewSet(viewsets.ModelViewSet):
    permission_classes = [TrustedGatewayAuthentication]

    def get_queryset(self):
        # Critical Security Gate: Only return records belonging to the current tenant
        return self.queryset.filter(tenant_id=self.request.tenant_id)

    def perform_create(self, serializer):
        # Enforce multi-tenant tagging upon record creation
        serializer.save(
            tenant_id=self.request.tenant_id,
            created_by=self.request.user_identity
        )

class CategoryViewSet(MultiTenantBaseViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

class ProductViewSet(MultiTenantBaseViewSet):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer