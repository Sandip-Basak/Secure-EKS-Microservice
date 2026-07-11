from django.db import models

# Create your models here.
from django.db import models

class Category(models.Model):
    tenant_id = models.CharField(max_length=64, db_index=True)
    name = models.CharField(max_length=255)

    def __str__(self):
        return f"[{self.tenant_id}] {self.name}"

class Product(models.Model):
    tenant_id = models.CharField(max_length=64, db_index=True)
    category = models.ForeignKey(Category, on_delete=models.CASCADE, related_name='products')
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    image = models.ImageField(upload_url='products/')  # Routes directly to S3
    created_by = models.CharField(max_length=255)

    def __str__(self):
        return self.name