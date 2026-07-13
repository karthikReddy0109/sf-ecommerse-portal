import { LightningElement, api } from 'lwc';
import {NavigationMixin} from 'lightning/navigation';

export default class ProductCard extends NavigationMixin(LightningElement) {
    @api product;
    
    get stockStatusLabel(){
        return this.product.stockStatus;
    }

    get isOutOfStock(){
        return this.product.stockStatus === 'Out of Stock';
    }

    get formattedPrice(){
        return '₹ ' + this.product.price;
    }

    get isInStock(){
        return this.product.stockStatus === 'In Stock';
    }
    get isLowStock(){
        return this.product.stockStatus === 'Low Stock';
    }

    handleView(e){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes:{
                recordId: this.product.id,
                objectApiName: 'Product__c',
                actionName: 'view'
            }
        })
    }

    handleAddToOrder(){
        const event = new CustomEvent('productselected', {
            detail:{
                productId: this.product.id,
                productName: this.product.name
            }
        });
        this.dispatchEvent(event);
    }
}