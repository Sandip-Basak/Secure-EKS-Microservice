from rest_framework import permissions

class TrustedGatewayAuthentication(permissions.BasePermission):
    """
    Validates identity based on trusted context passed from the API Gateway.
    Allows public read (GET), but requires attested identity for writes.
    """
    def has_permission(self, request, view):
        # Extract headers injected by our Node.js Gateway
        tenant_id = request.headers.get('X-Tenant-ID')
        user_sub = request.headers.get('X-User-Sub') # e.g., username/id from JWT
        
        if not tenant_id:
            return False # Drop connection. No tenant context provided.

        # Inject context into request object for easy filtering in views
        request.tenant_id = tenant_id
        request.user_identity = user_sub

        # Anyone can view data
        if request.method in permissions.SAFE_METHODS:
            return True

        # Write operations require an authenticated user identity from the Gateway
        return bool(user_sub)