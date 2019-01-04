pragma solidity ^0.5.0;

contract ArrayHelper {
  function removeValue(address[] memory array, address value) pure internal returns(address[] memory) {
    return removeAtIndex(array, indexOf(array, value));
  }


  function indexOf(address[] memory array, address value) pure internal returns(uint) {
    for(uint i = 0; i < array.length; i++){
      if(value == array[i]) return i;
    }
  }

  function removeAtIndex(address[] memory array, uint index) pure internal returns(address[] memory value) {
    require(index <= array.length);

    address[] memory arrayNew = new address[](array.length-1);
    for (uint i = 0; i<arrayNew.length; i++){
      if(i != index && i<index){
        arrayNew[i] = array[i];
      } else {
        arrayNew[i] = array[i+1];
      }
    }
    delete array;
    return arrayNew;
  }
}
