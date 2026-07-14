import { LightningElement, api } from 'lwc';

export default class OrderLineItemEditor extends LightningElement {
    @api lineItems;

    get hasLineItems(){
        return this.lineItems && this.lineItems.length > 0;
    }
}