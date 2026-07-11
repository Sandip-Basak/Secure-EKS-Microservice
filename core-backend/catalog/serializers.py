from rest_framework import serializers
from .models import Category, Product

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'tenant_id', 'name']
        # CRITICAL: tenant_id must be read-only. 
        # It is strictly injected by the view tier from the Gateway context.
        read_only_fields = ['id', 'tenant_id']


class ProductSerializer(serializers.ModelSerializer):
    # Optional: If you want to include the category details in the read response, 
    # you could use a nested serializer, but for strict CRUD operations, 
    # referencing the ID keeps payload overhead low.
    
    class Meta:
        model = Product
        fields = [
            'id', 
            'tenant_id', 
            'category', 
            'name', 
            'description', 
            'image', 
            'created_by'
        ]
        # CRITICAL: Prevent mass assignment. 
        # Under no circumstances should a client be allowed to supply or alter 
        # the tenant_id or the audit trail (created_by) via a POST/PUT payload.
        read_only_fields = ['id', 'tenant_id', 'created_by']

    def validate_category(self, value):
        """
        Cross-Tenant Data Leakage Guard.
        Ensures a user cannot associate a product with a category 
        belonging to a different tenant.
        """
        request = self.context.get('request')
        if request and hasattr(request, 'tenant_id'):
            if value.tenant_id != request.tenant_id:
                raise serializers.ValidationError(
                    "Invalid category selection. The requested category does not exist within your tenant scope."
                )
        return value