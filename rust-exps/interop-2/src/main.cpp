// src/main.cpp
#include <iostream>
#include <point.h>

int main() {
    Point p = {3, 4};
    float distance = rust_manhattan(&p);
    std::cout << "Distance: " << distance << std::endl;
    return 0;
}
