// include/point.h
#ifndef POINT_H
#define POINT_H

#ifdef __cplusplus
extern "C" {
#endif

struct Point {
    int x;
    int y;
};

float rust_manhattan(struct Point *p);

#ifdef __cplusplus
}
#endif

#endif  // POINT_H
