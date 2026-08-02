import { LightningElement, api } from 'lwc';

export default class DuplicateAccountDetector extends LightningElement {
    @api companyName;
    connectedCallback(){
        console.log('Company Name : ', this.companyName);
    }
}